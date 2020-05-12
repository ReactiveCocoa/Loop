import ReactiveSwift

public final class FeedbackLoop<State, Event> {
    public let lifetime: Lifetime
    internal let floodgate: Floodgate<State, Event>
    private let token: Lifetime.Token

    public var producer: SignalProducer<State, Never> {
        SignalProducer { observer, lifetime in
            self.floodgate.withValue { initial, hasStarted -> Void in
                if hasStarted {
                    // The feedback loop has started already, so the initial value has to be manually delivered.
                    // Uninitialized feedback loop that does not start immediately will emit the initial state
                    // when `start()` is called.
                    observer.send(value: initial)
                }

                lifetime += self.floodgate.stateDidChange.observe(observer)
            }
        }
    }

    public init(
        initial: State,
        reduce: @escaping (inout State, Event) -> Void,
        feedbacks: [Feedback]
    ) {
        (lifetime, token) = Lifetime.make()
        floodgate = Floodgate<State, Event>(state: initial, reducer: reduce)
        lifetime.observeEnded(floodgate.dispose)

        for feedback in feedbacks {
            lifetime += feedback
                .events(floodgate.stateDidChange.producer, floodgate)
        }
    }

    public func start() {
        floodgate.bootstrap()
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
        /// - important: The `state` producer provided to the setup closure **does not** replay the current state.
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
