import ReactiveSwift
import Foundation
#if canImport(Combine)
import Combine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class MainThreadLoopBox<State, Event>: LoopBoxBase<State, Event> {
    override var _mainThreadView: LoopBoxBase<State, Event> {
        self
    }

    override var lifetime: Lifetime {
        _lifetime
    }

    /// Loop Internal SPI
    override var _current: State {
        cached
    }

    #if canImport(Combine)
    override var objectWillChange: ObservableObjectPublisher { willChange }
    private var willChange = ObservableObjectPublisher()
    #endif

    override var producer: SignalProducer<State, Never> {
        return SignalProducer { observer, lifetime in
            precondition(Thread.isMainThread)

            observer.send(value: self.cached)
            lifetime += self.didChange.observe(observer)
        }
    }

    private var cached: State {
        willSet {
            #if canImport(Combine)
            willChange.send()
            #endif
        }
        didSet { didChangeObserver.send(value: cached) }
    }

    private let (didChange, didChangeObserver) = Signal<State, Never>.pipe()

    private let _lifetime: Lifetime
    private let _send: (Event) -> Void

    private var disposable: Disposable?

    init(root: RootLoopBox<State, Event>) {
        precondition(Thread.isMainThread)

        // NOTE: Do not retain `root` here, since `root` retains the created MainThreadLoopBox.

        cached = root._current
        _lifetime = root.lifetime
        _send = { [weak root] in root?.send($0) }

        super.init()

        disposable = root.producer
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] state in
                self.cached = state
            }
    }

    deinit {
        disposable?.dispose()
        didChangeObserver.sendCompleted()
    }

    override func scoped<S, E>(
        to scope: KeyPath<State, S>,
        event: @escaping (E) -> Event
    ) -> LoopBoxBase<S, E> {
        ScopedLoopBox(root: self, value: scope, event: event)
    }

    override func send(_ event: Event) {
        _send(event)
    }
}
