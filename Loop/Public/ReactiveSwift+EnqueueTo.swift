import ReactiveSwift

extension Signal where Error == Never {
    /// Enqueue all received values to the given `FeedbackEventConsumer`.
    ///
    /// - note: This converts the `Signal` to be a `SignalProducer<Never, Never>` accepted by `Feedback`.
    public func enqueue(to consumer: FeedbackEventConsumer<Value>) -> SignalProducer<Never, Never> {
        producer.enqueue(to: consumer)
    }
}

extension SignalProducer where Error == Never {
    /// Enqueue all received values to the given `FeedbackEventConsumer`.
    ///
    /// If the producer is interrupted, e.g. explicitly by users, or by an operator like `flatMap(.latest)`, unprocessed
    /// events would be removed from the loop internal event queue.
    public func enqueue(to consumer: FeedbackEventConsumer<Value>) -> SignalProducer<Never, Never> {
        SignalProducer<Never, Never> { observer, lifetime in
            let token = Token()

            lifetime += self.startWithValues { event in
                consumer.process(event, for: token)
            }

            lifetime.observeEnded { consumer.dequeueAllEvents(for: token) }
        }
    }

    internal func enqueueNonCancelling(to consumer: FeedbackEventConsumer<Value>) -> SignalProducer<Never, Never> {
        SignalProducer<Never, Never> { observer, lifetime in
            let token = Token()

            lifetime += self.startWithValues { event in
                consumer.process(event, for: token)
            }
        }
    }
}
