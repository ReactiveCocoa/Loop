import ReactiveSwift
import Foundation
#if canImport(Combine)
import Combine
#endif

internal class ScopedLoopBox<RootState, RootEvent, ScopedState, ScopedEvent>: LoopBoxBase<ScopedState, ScopedEvent> {
    // MARK: [BEGIN] Loop Internal SPIs
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    override var _mainThreadView: LoopBoxBase<ScopedState, ScopedEvent> {
        ScopedLoopBox(root: root._mainThreadView, value: value, event: eventTransform)
    }

    override var _current: ScopedState {
        root._current[keyPath: value]
    }

    #if canImport(Combine)
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    override var objectWillChange: ObservableObjectPublisher {
        // NOTE: This traps when `root` is not a `MainThreadLoopBox`. See `RootLoopBox.objectWillChange` for the
        //       rationale.
        root.objectWillChange
    }
    #endif
    // MARK: [END] Loop Internal SPIs

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
    // MARK: [BEGIN] Loop Internal SPIs
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    override var _mainThreadView: LoopBoxBase<State, Event> {
        precondition(Thread.isMainThread)

        if _lazyMainThreadLoopBox == nil {
            _lazyMainThreadLoopBox = MainThreadLoopBox(root: self)
        } else {
            precondition(_lazyMainThreadLoopBox is MainThreadLoopBox<State, Event>)
        }

        return _lazyMainThreadLoopBox
    }

    private var _lazyMainThreadLoopBox: LoopBoxBase<State, Event>!

    override var _current: State {
        floodgate.withValue { state, _ in state }
    }

    #if canImport(Combine)
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    override var objectWillChange: ObservableObjectPublisher {
        // `objectWillChange` is an internal SPI for implementing `_mainThreadView`, and is not intended to support
        // a public conformance to `ObservableObject` on `Loop`. This is because `ObservableObject` requires that
        // changes to be published only on the main thread, while `Loop` is designed to be runnable on background
        // threads.
        //
        // SwiftUI Loop property wrappers use `_mainThreadView`, which maintains a cache that is updated at the pace of
        // the main thread run loop.
        unsupportedFeature()
    }
    #endif
    // MARK: [END] Loop Internal SPIs

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
    // MARK: [BEGIN] Loop Internal SPIs
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    var _mainThreadView: LoopBoxBase<State, Event> { subclassMustImplement() }
    var _current: State { subclassMustImplement() }

    #if canImport(Combine)
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    var objectWillChange: ObservableObjectPublisher { subclassMustImplement() }
    #endif
    // MARK: [END} Loop Internal SPIs

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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension LoopBoxBase: ObservableObject {}

@inline(never)
private func subclassMustImplement(function: StaticString = #function) -> Never {
    fatalError("Subclass must implement `\(function)`.")
}

@inline(never)
private func unsupportedFeature(function: StaticString = #function) -> Never {
    fatalError("The class is not intended to support `\(function)`.")
}
