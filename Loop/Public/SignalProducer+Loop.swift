import ReactiveSwift

extension SignalProducer where Error == Never {

    /// Feedback-controlled State Machine. The system state is represented as a `State` parameter.
    /// Events are represented by an `Event` parameter. It represents all the possible Events that may occur in the System
    /// Feedback defines an effect that may change the State.

    /// - parameters:
    ///     - initial: An initial `State` of the system.
    ///     - scheduler: A Scheduler used for Events synchronisation
    ///     - reduce: A function that produces a new State of a system by applying an Event
    ///     - feedbacks: A Feedback loops that produces Events depending on the system's `State`
    ///     - returns: A SignalProducer that emits current the state of the System
    public static func feedbackLoop<Event>(
        initial: Value,
        reduce: @escaping (inout Value, Event) -> Void,
        feedbacks: [Loop<Value, Event>.Feedback]
    ) -> SignalProducer<Value, Never> {
        return SignalProducer.deferred { downstreamLifetime in
            let feedbackLoop = RootLoopBox(initial: initial, reducer: reduce)
            downstreamLifetime.observeEnded(feedbackLoop.stop)
            return feedbackLoop.producer.on(started: {
                feedbackLoop.start(with: feedbacks)
            })
         }
    }

    /// Feedback-controlled State Machine. The system state is represented as a `State` parameter.
    /// Events are represented by `Event` parameter. It represents all possible Events that may occur in the System
    /// Feedback defines an effect that may change the State.

    /// - parameters:
    ///     - initial: An initial `State` of the system.
    ///     - reduce: A that produces a new State of the system by applying an Event
    ///     - feedbacks: A Feedback loops that produces Events depending on the system's state.
    ///     - returns: A SignalProducer that emits current the state of the System
    public static func feedbackLoop<Event>(
        initial: Value,
        reduce: @escaping (inout Value, Event) -> Void,
        feedbacks: Loop<Value, Event>.Feedback...
    ) -> SignalProducer<Value, Error> {
        return feedbackLoop(initial: initial, reduce: reduce, feedbacks: feedbacks)
    }
}
