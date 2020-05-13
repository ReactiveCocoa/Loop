import ReactiveSwift

public final class FeedbackLoop<State, Event> {
    public let lifetime: Lifetime
    internal let floodgate: Floodgate<State, Event>
    private let token: Lifetime.Token

    public var producer: SignalProducer<State, Never> {
        floodgate.producer
    }

    private let feedbacks: [Feedback]

    public init(
        initial: State,
        reduce: @escaping (inout State, Event) -> Void,
        feedbacks: [Feedback]
    ) {
        (lifetime, token) = Lifetime.make()
        self.floodgate = Floodgate<State, Event>(state: initial, reducer: reduce)
        self.feedbacks = feedbacks

        lifetime.observeEnded(floodgate.dispose)
    }

    public func start() {
        floodgate.bootstrap(with: feedbacks)
    }

    public func stop() {
        token.dispose()
    }

    deinit {
        stop()
    }
}

extension FeedbackLoop {
    public struct Feedback {
        let events: (_ state: SignalProducer<State, Never>, _ output: FeedbackEventConsumer<Event>) -> Disposable

        /// Private designated initializer. See the public designated initializer below.
        fileprivate init(
            startWith events: @escaping (_ state: SignalProducer<State, Never>, _ output: FeedbackEventConsumer<Event>) -> Disposable
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
                _ state: SignalProducer<State, Never>,
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
        public init<U, Effect: SignalProducerConvertible>(
            compacting transform: @escaping (SignalProducer<State, Never>) -> SignalProducer<U, Never>,
            effects: @escaping (U) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.events = { state, output in
                // NOTE: `observe(on:)` should be applied on the inner producers, so
                //       that cancellation due to state changes would be able to
                //       cancel outstanding events that have already been scheduled.
                transform(state)
                    .flatMap(.latest) { effects($0).producer.enqueue(to: output) }
                    .start()
            }
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
        public init<Control: Equatable, Effect: SignalProducerConvertible>(
            skippingRepeated transform: @escaping (State) -> Control?,
            effects: @escaping (Control) -> Effect
        ) where Effect.Value == Event, Effect.Error == Never {
            self.init(compacting: { $0.map(transform).skipRepeats() },
                      effects: { $0.map(effects)?.producer ?? .empty })
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
            self.init(compacting: { $0.map(transform) },
                      effects: { $0.map(effects)?.producer ?? .empty })
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
            self.init(compacting: { $0 },
                      effects: { state -> SignalProducer<Event, Never> in
                          predicate(state) ? effects(state).producer : .empty
                      })
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
            self.init(compacting: { $0 }, effects: effects)
        }
        
        public static var input: (feedback: Feedback, observer: (Event) -> Void) {
            let pipe = Signal<Event, Never>.pipe()
            let feedback = Feedback(source: pipe.output, as: { $0 })
            return (feedback, pipe.input.send)
        }
        
        public static func pullback<LocalState, LocalEvent>(
            feedback: FeedbackLoop<LocalState, LocalEvent>.Feedback,
            value: KeyPath<State, LocalState>,
            event: @escaping (LocalEvent) -> Event
        ) -> Feedback {
            return Feedback(startWith: { (state, consumer) in
                return feedback.events(
                    state.map(value),
                    consumer.pullback(event)
                )
            })
        }
        
        public static func combine(_ feedbacks: FeedbackLoop<State, Event>.Feedback...) -> Feedback {
            return Feedback(startWith: { (state, consumer) in
                return feedbacks.map { (feedback) in
                    feedback.events(state, consumer)
                }
                .reduce(into: CompositeDisposable()) { (composite, disposable) in
                    composite += disposable
                }
            })
        }
    }
}

extension FeedbackLoop.Feedback {
    @available(*, deprecated, renamed:"init(_:)")
    public static func custom(
        _ setup: @escaping (
            _ state: SignalProducer<State, Never>,
            _ output: FeedbackEventConsumer<Event>
        ) -> Disposable
    ) -> FeedbackLoop.Feedback {
        return FeedbackLoop.Feedback(events: setup)
    }

    @available(*, deprecated, renamed:"init(_:)")
    public init(
        events: @escaping (
            _ state: SignalProducer<State, Never>,
            _ output: FeedbackEventConsumer<Event>
        ) -> Disposable
    ) {
        self.events = { events($0.producer, $1) }
    }
}
