import ReactiveSwift

@available(*, deprecated, renamed:"Loop")
public typealias FeedbackLoop<State, Event> = Loop<State, Event>

@available(*, deprecated, renamed:"Store")
public typealias Store<State, Event> = Loop<State, Event>

public final class Loop<State, Event> {
    public var producer: SignalProducer<State, Never> {
        box.producer
    }

    public var context: SignalProducer<Context<State, Event>, Never> {
        let forward: (Event) -> Void = { [weak self] in self?.send($0) }

        return producer.map { state in
            Context(state: state, forward: forward)
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public var binding: LoopBinding<State, Event> {
        LoopBinding(self)
    }

    internal let box: LoopBoxBase<State, Event>

    private init(box: LoopBoxBase<State, Event>) {
        self.box = box
    }

    public init(
        initial: State,
        reducer: @escaping (inout State, Event) -> Void,
        feedbacks: [Loop<State, Event>.Feedback]
    ) {
        let box = RootLoopBox(initial: initial, reducer: reducer)
        box.start(with: feedbacks)

        self.box = box
    }

    public func send(_ event: Event) {
        box.send(event)
    }

    public func scoped<ScopedState, ScopedEvent>(
        to scope: @escaping (State) -> ScopedState,
        event: @escaping (ScopedEvent) -> Event
    ) -> Loop<ScopedState, ScopedEvent> {
        return Loop<ScopedState, ScopedEvent>(
            box: box.scoped(to: scope, event: event)
        )
    }

    public func scoped<ScopedEvent>(
        event: @escaping (ScopedEvent) -> Event
    ) -> Loop<State, ScopedEvent> {
        return Loop<State, ScopedEvent>(
            box: box.scoped(to: { $0 }, event: event)
        )
    }

    /// Create a scoped `Loop` from `self` which will not accept any input from `Loop.send(_:)`. Note that sending
    /// events on `self` through `Loop.send(_:)` remains unaffected.
    public func ignoringInput() -> Loop<State, Never> {
        return Loop<State, Never>(
            box: box.scoped(to: { $0 }, event: { _ in fatalError() })
        )
    }

    public func pause() {
        box.pause()
    }

    public func resume() {
        box.resume()
    }
}

extension Loop {
    @available(*, unavailable, message:"Subscribe to the loop using `producer`, `context` or Loop Bindings for SwiftUI.")
    public var state: Property<Context<State, Event>> { fatalError() }

    @available(*, deprecated, renamed:"init(initial:reducer:feedbacks:)")
    public convenience init(
        initial: State,
        reduce: @escaping (inout State, Event) -> Void,
        feedbacks: [Loop<State, Event>.Feedback]
    ) {
        self.init(initial: initial, reducer: reduce, feedbacks: feedbacks)
    }

    @available(*, deprecated, renamed:"scoped(to:event:)")
    public func view<ScopedState, ScopedEvent>(
        value: KeyPath<State, ScopedState>,
        event: @escaping (ScopedEvent) -> Event
    ) -> Loop<ScopedState, ScopedEvent> {
        return scoped(to: { $0[keyPath: value] }, event: event)
    }

    @available(*, unavailable, message:"Loop now starts automatically.")
    public func start() {}

    @available(*, unavailable, message:"Loop stops when deinitialized.")
    public func stop() {}
}
