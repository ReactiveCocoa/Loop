import SwiftUI
#if canImport(Combine)

import Combine
import ReactiveSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal final class SwiftUISubscription<State, Event>: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    var latestValue: State!
    private(set) var hasStarted = false

    private var disposable: Disposable?

    init() {}

    deinit {
        disposable?.dispose()
    }

    func attach(to loop: Loop<State, Event>) {
        guard hasStarted == false else { return }
        hasStarted = true

        latestValue = loop.box._current
        disposable = loop.producer
            .observe(on: UIScheduler())
            .startWithValues { [weak self] state in
                guard let self = self else { return }
                self.latestValue = state
                self.objectWillChange.send()
            }
    }
}

#endif
