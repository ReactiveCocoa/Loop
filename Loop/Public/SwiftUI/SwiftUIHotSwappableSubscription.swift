#if canImport(Combine)

import Combine
import ReactiveSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal final class SwiftUIHotSwappableSubscription<State, Event>: ObservableObject {
    let objectWillChange = ObjectWillChangePublisher()

    private weak var attachedBox: LoopBoxBase<State, Event>!
    private var cancellable: Cancellable?

    init() {}

    deinit {
        cancellable?.cancel()
    }

    func currentState(in loop: Loop<State, Event>) -> State {
        let mainThreadBox = loop.box._mainThreadView

        if attachedBox !== mainThreadBox {
            cancellable?.cancel()

            attachedBox = mainThreadBox
            cancellable = mainThreadBox.objectWillChange.sink(receiveValue: objectWillChange.send)
        }

        return attachedBox._current
    }
}

#endif
