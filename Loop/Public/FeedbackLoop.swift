import ReactiveSwift

extension Loop {
    public struct Feedback {
        let events: (_ state: SignalProducer<(State, Event?), Never>, _ output: FeedbackEventConsumer<Event>) -> Disposable

        /// Private designated initializer. See the public designated initializer below.
        fileprivate init(
            startWith events: @escaping (_ state: SignalProducer<(State, Event?), Never>, _ output: FeedbackEventConsumer<Event>) -> Disposable
        ) {
            self.events = events
        }

        /// Creates a custom Feedback, with the complete liberty of defining the data flow.
        ///
        /// Consider using the standard `Feedback` variants, before deriving down to use this desginated initializer.
        ///
        /// Events must be explicitly enqueued using `SignalProducer.enqueue(to:)` with the `FeedbackEventConsumer`
        /// provided to the setup closure. `enqueue(to:)` respects producer cancellation and removes outstanding events
        /// from the loop internal event queue.
        ///
        /// This is useful if you wish to discard events when the state changes in certain ways. For example,
        /// `Feedback(skippingRepeated:effects:)` enqueues events inside `flatMap(.latest)`, so that unprocessed events
        /// are automatically removed when the inner producer has switched.
        ///
        /// ## State producer in the `setup` closure
        /// The setup closure provides you a `state` producer — it replays the latest state at starting time, and then
        /// publishes all state changes.
        ///
        /// Loop guarantees only that this `state` producer is **eventually consistent** with events emitted by your
        /// feedback. This means you should not make any strong assumptions on events you enqueued being immediately
        /// reflected by `state`.
        ///
        /// For example, if you start the `state` producer again, synchronously after enqueuing an event, the event
        /// may not have been processed yet, and therefore the assertion would fail:
        /// ```swift
        /// Feedback { state, output in
        ///     state
        ///        .filter { $0.apples.isEmpty == false }
        ///        .map(value: Event.eatAllApples)
        ///        .take(first: 1)
        ///        .concat(
        ///            state
        ///                .take(first: 1)
        ///                .on(value: { state in
        ///                    guard state.apples.isEmpty else { return }
        ///
        ///                    // ❌🙅‍♀️ No guarantee that this is true.
        ///                    fatalError("It should have eaten all the apples!")
        ///                })
        ///        )
        ///        .enqueue(to: output)
        /// }
        /// ```
        ///
        /// You can however expect it to be eventually consistent:
        /// ```swift
        /// Feedback { state, output in
        ///     state
        ///        .filter { $0.apples.isEmpty == false }
        ///        .map(value: Event.eatAllApples)
        ///        .take(first: 1)
        ///        .concat(
        ///            state
        ///                .filter { $0.apples.isEmpty } // ℹ️ Watching specifically for the ideal state.
        ///                .take(first: 1)
        ///                .on(value: { state in
        ///                    guard state.apples.isEmpty else { return }
        ///
        ///                    // ✅👍 We would eventually observe this, when the loop event queue
        ///                    //      has caught up with `.eatAppleApples` we enqueued earlier.
        ///                    fatalError("It should have eaten all the apples!")
        ///                })
        ///        )
        ///        .enqueue(to: output)
        /// }
        /// ```
        ///
        /// - parameters:
        ///   - setup: The setup closure to construct a data flow producing events in respond to changes from `state`,
        ///             and having them consumed by `output` using the `SignalProducer.enqueue(to:)` operator.
        public init(
            events: @escaping (
                _ statesAndEvents: SignalProducer<(State, Event?), Never>,
                _ output: FeedbackEventConsumer<Event>
            ) -> SignalProducer<Never, Never>
        ) {
            self.events = { events($0, $1).start() }
        }

        /// Creates a Feedback that observes an external producer and maps it to an event.
        ///
        /// - parameters:
        ///   - setup: The setup closure to construct a data flow producing events in respond to changes from `state`,
        ///             and having them consumed by `output` using the `SignalProducer.enqueue(to:)` operator.
        public init<Values: SignalProducerConvertible>(
            source: Values,
            as transform: @escaping (Values.Value) -> Event
        ) where Values.Error == Never {
            self.init { _, output in
                source.producer.map(transform).enqueueNonCancelling(to: output)
            }
        }

        /// Creates a Feedback which re-evaluates the given effect every time the
        /// `Signal` derived from the latest state yields a new value.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - transform: The transform which derives a `Signal` of values from the
        ///                latest state.
        ///   - effects: The side effect accepting transformed values produced by
        ///              `transform` and yielding events that eventually affect
        ///              the state.
        @available(*, deprecated, renamed:"init(compactingState:effects:)")
        public init<U, Effect: SignalProducerConvertible>(
            compacting transform: @escaping (SignalProducer<State, Never>) -> SignalProducer<U, Never>,
            effects: @escaping (U) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            events = { state, output in
                // NOTE: `observe(on:)` should be applied on the inner producers, so
                //       that cancellation due to state changes would be able to
                //       cancel outstanding events that have already been scheduled.
                transform(state.map(\.0))
                    .flatMap(.latest) { effects($0).producer.enqueue(to: output) }
                    .start()
            }
        }
        
        /// Creates a Feedback which re-evaluates the given effect every time the
        /// `Signal` derived from the latest state yields a new value.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - transform: The transform which derives a `Signal` of values from the
        ///                latest state.
        ///   - effects: The side effect accepting transformed values produced by
        ///              `transform` and yielding events that eventually affect
        ///              the state.
        public init<U, Effect: SignalProducerConvertible>(
            compactingState transform: @escaping (SignalProducer<State, Never>) -> SignalProducer<U, Never>,
            effects: @escaping (U) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            events = { state, output in
                // NOTE: `observe(on:)` should be applied on the inner producers, so
                //       that cancellation due to state changes would be able to
                //       cancel outstanding events that have already been scheduled.
                transform(state.map(\.0))
                    .flatMap(.latest) { effects($0).producer.enqueue(to: output) }
                    .start()
            }
        }
        
        public init<U, Effect: SignalProducerConvertible>(
            compactingEvents transform: @escaping (SignalProducer<Event, Never>) -> SignalProducer<U, Never>,
            effects: @escaping (U) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            events = { state, output in
                // NOTE: `observe(on:)` should be applied on the inner producers, so
                //       that cancellation due to state changes would be able to
                //       cancel outstanding events that have already been scheduled.
                transform(state.compactMap(\.1))
                    .flatMap(.latest) { effects($0).producer.enqueue(to: output) }
                    .start()
            }
        }

        /// Creates a Feedback which re-evaluates the given effect every time the
        /// `Signal` derived from the latest state yields a new value.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - transform: The transform which derives a `Signal` of values from the
        ///                latest state.
        ///   - effects: The side effect accepting transformed values produced by
        ///              `transform` and yielding events that eventually affect
        ///              the state.
        public static func compacting<U, Effect: SignalProducerConvertible>(
            state transform: @escaping (SignalProducer<State, Never>) -> SignalProducer<U, Never>,
            effects: @escaping (U) -> Effect
        ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
            return Feedback(compactingState: transform, effects: effects)
        }

        public static func compacting<U, Effect: SignalProducerConvertible>(
            events transform: @escaping (SignalProducer<Event, Never>) -> SignalProducer<U, Never>,
            effects: @escaping (U) -> Effect
        ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
            return Feedback(compactingEvents: transform, effects: effects)
        }

        /// Creates a Feedback which re-evaluates the given effect every time the
        /// state changes, and the transform consequentially yields a new value
        /// distinct from the last yielded value.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - transform: The transform to apply on the state.
        ///   - effects: The side effect accepting transformed values produced by
        ///              `transform` and yielding events that eventually affect
        ///              the state.
        @available(*, deprecated, renamed:"init(skippingRepeatedState:effects:)")
        public init<Control: Equatable, Effect: SignalProducerConvertible>(
            skippingRepeated transform: @escaping (State) -> Control?,
            effects: @escaping (Control) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(skippingRepeatedState: transform, effects: effects)
        }
        
        public init<Control: Equatable, Effect: SignalProducerConvertible>(
            skippingRepeatedState transform: @escaping (State) -> Control?,
            effects: @escaping (Control) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(
                compactingState: { $0.map(transform).skipRepeats() },
                effects: { $0.map(effects)?.producer ?? .empty }
            )
        }
        
        public init<Payload: Equatable, Effect: SignalProducerConvertible>(
            skippingRepeatedEvents transform: @escaping (Event) -> Payload?,
            effects: @escaping (Payload) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(
                compactingEvents: { $0.map(transform).skipRepeats() },
                effects: { $0.map(effects)?.producer ?? .empty }
            )
        }

        public static func skippingRepeated<Control: Equatable, Effect: SignalProducerConvertible>(
            state transform: @escaping (State) -> Control?,
            effects: @escaping (Control) -> Effect
        ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
            Feedback(skippingRepeatedState: transform, effects: effects)
        }

        public static func skippingRepeated<Payload: Equatable, Effect: SignalProducerConvertible>(
            events transform: @escaping (Event) -> Payload?,
            effects: @escaping (Payload) -> Effect
        ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
            Feedback(skippingRepeatedEvents: transform, effects: effects)
        }

        /// Creates a Feedback which re-evaluates the given effect every time the
        /// state changes.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - transform: The transform to apply on the state.
        ///   - effects: The side effect accepting transformed values produced by
        ///              `transform` and yielding events that eventually affect
        ///              the state.
        public init<Control, Effect: SignalProducerConvertible>(
            lensing transform: @escaping (State) -> Control?,
            effects: @escaping (Control) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(
                compactingState: { $0.map(transform) },
                effects: { $0.map(effects)?.producer ?? .empty }
            )
        }
        
        /// Creates a Feedback which re-evaluates the given effect every time the
        /// a specific even is emitted.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - transform: The transform to apply on the state.
        ///   - effects: The side effect accepting transformed values produced by
        ///              `transform` and yielding events that eventually affect
        ///              the state.
        public init<Payload, Effect: SignalProducerConvertible>(
            extractingPayload transform: @escaping (Event) -> Payload?,
            effects: @escaping (Payload) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(
                compactingEvents: { $0.map(transform) },
                effects: { $0.map(effects)?.producer ?? .empty }
            )
        }
        /// Creates a Feedback which re-evaluates the given effect every time the
        /// state changes.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - transform: The transform to apply on the state.
        ///   - effects: The side effect accepting transformed values produced by
        ///              `transform` and yielding events that eventually affect
        ///              the state.

        public static func lensing<Control, Effect: SignalProducerConvertible>(
            state transform: @escaping (State) -> Control?,
            effects: @escaping (Control) -> Effect
        ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
            Feedback(lensing: transform, effects: effects)
        }

        public static func extracting<Payload, Effect: SignalProducerConvertible>(
            payload transform: @escaping (Event) -> Payload?,
            effects: @escaping (Payload) -> Effect
        ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
            Feedback(extractingPayload: transform, effects: effects)
        }
        
        /// Creates a Feedback which re-evaluates the given effect every time the
        /// given predicate passes.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - predicate: The predicate to apply on the state.
        ///   - effects: The side effect accepting the state and yielding events
        ///              that eventually affect the state.
        public init<Effect: SignalProducerConvertible>(
            predicate: @escaping (State) -> Bool,
            effects: @escaping (State) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(
                compactingState: { $0 },
                effects: { state -> SignalProducer<Event, Never> in
                    predicate(state) ? effects(state).producer : .empty
                }
            )
        }

        /// Create a feedback which (re)starts the effect every time `transform` emits a non-nil value after a sequence
        /// of `nil`, and ignore all the non-nil value afterwards. It does so until `transform` starts emitting a `nil`,
        /// at which point the feedback cancels any outstanding effect.
        ///
        /// - parameters:
        ///   - transform: The transform to select a specific part of the state, or to cancel the outstanding effect
        ///                by returning `nil`.
        ///   - effects: The side effect accepting the first non-nil value produced by `transform`, and yielding events
        ///              that eventually affect the state.
        public init<Value, Effect: SignalProducerConvertible>(
          firstValueAfterNil transform: @escaping (State) -> Value?,
          effects: @escaping (Value) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
          self.init(
            compacting: { state in
              state
                .scan(into: (false, nil)) { (temp: inout (lastWasNil: Bool, output: NilEdgeTransition<Value>?), state: State) in
                  let result = transform(state)
                  temp.output = nil

                  switch (temp.lastWasNil, result) {
                  case (true, .none), (false, .some):
                    return
                  case let (true, .some(value)):
                    temp.lastWasNil = false
                    temp.output = .populated(value)
                  case (false, .none):
                    temp.lastWasNil = true
                    temp.output = .cleared
                  }
              }
              .compactMap { $0.output }
            },
            effects: { transition -> SignalProducer<Event, Never> in
              switch transition {
              case let .populated(value):
                return effects(value).producer
              case .cleared:
                return .empty
              }
            }
          )
        }

        /// Create a feedback which (re)starts the effect every time `transform` emits a non-nil value after a sequence
        /// of `nil`, and ignore all the non-nil value afterwards. It does so until `transform` starts emitting a `nil`,
        /// at which point the feedback cancels any outstanding effect.
        ///
        /// - parameters:
        ///   - transform: The transform to select a specific part of the state, or to cancel the outstanding effect
        ///                by returning `nil`.
        ///   - effects: The side effect accepting the first non-nil value produced by `transform`, and yielding events
        ///              that eventually affect the state.
        public static func firstValueAfterNil<Value, Effect: SignalProducerConvertible>(
            _ transform: @escaping (State) -> Value?,
            effects: @escaping (Value) -> Effect
        ) -> Feedback where Effect.Value == Event, Effect.Error == Never {
            self.init(firstValueAfterNil: transform, effects: effects)
        }

        /// Creates a Feedback which re-evaluates the given effect every time the
        /// state changes.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - effects: The side effect accepting the state and yielding events
        ///              that eventually affect the state.
        public init<Effect: SignalProducerConvertible>(
            effects: @escaping (State) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(compactingState: { $0 }, effects: effects)
        }
        
        /// Creates a Feedback which re-evaluates the given effect every time the
        /// state changes with the Event that caused the change.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - effects: The side effect accepting the state and yielding events
        ///              that eventually affect the state.
        init<Effect: SignalProducerConvertible>(
            middleware effect: @escaping (State, Event) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(events: { state, output in
                state.compactMap { s, e -> (State, Event)? in
                    guard let e = e else {
                        return nil
                    }
                    return (s, e)
                }
                .flatMap(.latest) {
                    effect($0, $1).producer.enqueue(to: output)
                }
            })
        }
        
        public static func middleware<Effect: SignalProducerConvertible>(
            effect: @escaping (State, Event) -> Effect
        ) -> Self where Effect.Value == Event, Effect.Error == Never {
            Feedback(middleware: effect)
        }

        public static var input: (feedback: Feedback, observer: (Event) -> Void) {
            let pipe = Signal<Event, Never>.pipe()
            let feedback = Feedback(source: pipe.output) { $0 }
            return (feedback, pipe.input.send)
        }

        public static func pullback<LocalState, LocalEvent>(
            feedback: Loop<LocalState, LocalEvent>.Feedback,
            value: KeyPath<State, LocalState>,
            embedEvent: @escaping (LocalEvent) -> Event,
            extractEvent: @escaping (Event) -> LocalEvent?
        ) -> Feedback {
            return feedback.pullback(value: value, embedEvent: embedEvent, extractEvent: extractEvent)
        }
        
        public func pullback<GlobalState, GlobalEvent>(
            value: KeyPath<GlobalState, State>,
            embedEvent: @escaping (Event) -> GlobalEvent,
            extractEvent: @escaping (GlobalEvent) -> Event?
        ) -> Loop<GlobalState, GlobalEvent>.Feedback {
            return Loop<GlobalState, GlobalEvent>.Feedback { (state, consumer)  in
                self.events(
                    state.map {
                        ($0.0[keyPath: value], $0.1.flatMap(extractEvent))
                    },
                    consumer.pullback(embedEvent)
                )
            }
        }

        public static func combine(_ feedbacks: Loop<State, Event>.Feedback...) -> Feedback {
            return Feedback { state, consumer in
                feedbacks.map { feedback in
                    feedback.events(state, consumer)
                }
                .reduce(into: CompositeDisposable()) { composite, disposable in
                    composite += disposable
                }
            }
        }
    }
}

private enum NilEdgeTransition<Value> {
  case populated(Value)
  case cleared
}
