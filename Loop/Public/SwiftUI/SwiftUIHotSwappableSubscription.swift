#if canImport(Combine)

import Combine
import ReactiveSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal final class SwiftUIHotSwappableSubscription<State, Event>: ObservableObject {

    @Published private var latestValue: State!
    private weak var attachedLoop: Loop<State, Event>?
    private var disposable: Disposable?

    init() {}

    deinit {
        disposable?.dispose()
    }

    func currentState(in loop: Loop<State, Event>) -> State {
        if attachedLoop !== loop {
            disposable?.dispose()

            latestValue = loop.box._current

            disposable = loop.producer
                .observe(on: UIScheduler())
                .startWithValues { [weak self] state in
                    guard let self = self else { return }
                    self.latestValue = state
                }
        }

        return latestValue
    }
}

#endif
