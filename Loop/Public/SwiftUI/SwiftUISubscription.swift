#if canImport(Combine)

import Combine
import ReactiveSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal final class SwiftUISubscription<State, Event>: ObservableObject {

    @Published var latestValue: State
    private var disposable: Disposable?

    init(loop: Loop<State, Event>) {
        latestValue = loop.box._current
        disposable = loop.producer
            .observe(on: UIScheduler())
            .startWithValues { [weak self] state in
                guard let self = self else { return }
                self.latestValue = state
            }
    }

    deinit {
        disposable?.dispose()
    }
}

#endif
