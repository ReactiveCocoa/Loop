import ReactiveSwift

internal class ScopedLoopBox<RootState, RootEvent, ScopedState, ScopedEvent>: LoopBoxBase<ScopedState, ScopedEvent> {
    override var producer: SignalProducer<ScopedState, Never> {
        root.producer.map(value)
    }

    override var lifetime: Lifetime {
        root.lifetime
    }

    private let root: LoopBoxBase<RootState, RootEvent>
    private let value: KeyPath<RootState, ScopedState>
    private let eventTransform: (ScopedEvent) -> RootEvent

    init(
        root: LoopBoxBase<RootState, RootEvent>,
        value: KeyPath<RootState, ScopedState>,
        event: @escaping (ScopedEvent) -> RootEvent
    ) {
        self.root = root
        self.value = value
        self.eventTransform = event
    }

    override func send(_ event: ScopedEvent) {
        root.send(eventTransform(event))
    }

    override func scoped<S, E>(
        to scope: KeyPath<ScopedState, S>,
        event: @escaping (E) -> ScopedEvent
    ) -> LoopBoxBase<S, E> {
        return ScopedLoopBox<RootState, RootEvent, S, E>(
            root: self.root,
            value: value.appending(path: scope),
            event: { [eventTransform] in eventTransform(event($0)) }
        )
    }
}

internal class RootLoopBox<State, Event>: LoopBoxBase<State, Event> {
    override var lifetime: Lifetime {
        _lifetime
    }

    let floodgate: Floodgate<State, Event>
    private let _lifetime: Lifetime
    private let token: Lifetime.Token
    private let input = Loop<State, Event>.Feedback.input

    override var producer: SignalProducer<State, Never> {
        floodgate.producer
    }

    init(
        initial: State,
        reducer: @escaping (inout State, Event) -> Void
    ) {
        (_lifetime, token) = Lifetime.make()
        floodgate = Floodgate<State, Event>(state: initial, reducer: reducer)
        _lifetime.observeEnded(floodgate.dispose)

        super.init()
    }

    override func scoped<S, E>(
        to scope: KeyPath<State, S>,
        event: @escaping (E) -> Event
    ) -> LoopBoxBase<S, E> {
        ScopedLoopBox(root: self, value: scope, event: event)
    }

    func start(with feedbacks: [Loop<State, Event>.Feedback]) {
        floodgate.bootstrap(with: feedbacks + [input.feedback])
    }

    func stop() {
        token.dispose()
    }

    override func send(_ event: Event) {
        input.observer(event)
    }

    deinit {
        token.dispose()
    }
}

internal class LoopBoxBase<State, Event> {
    var lifetime: Lifetime { subclassMustImplement() }
    var producer: SignalProducer<State, Never> { subclassMustImplement() }

    func send(_ event: Event) { subclassMustImplement() }

    func scoped<S, E>(
        to scope: KeyPath<State, S>,
        event: @escaping (E) -> Event
    ) -> LoopBoxBase<S, E> {
        subclassMustImplement()
    }
}

@inline(never)
private func subclassMustImplement(function: StaticString = #function) -> Never {
    fatalError("Subclass must implement `\(function)`.")
}
