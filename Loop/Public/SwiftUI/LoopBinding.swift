#if canImport(SwiftUI) && canImport(Combine)

import SwiftUI
import Combine
import ReactiveSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct LoopBinding<State, Event>: DynamicProperty {
    @ObservedObject
    private var box: LoopBoxBase<State, Event>

    @inlinable
    public var wrappedValue: State {
        acknowledgedState
    }

    public var projectedValue: LoopBinding<State, Event> {
        self
    }

    @usableFromInline
    internal var acknowledgedState: State

    public init(_ loop: Loop<State, Event>) {
        let mainThreadBox = loop.box._mainThreadView
        self.box = mainThreadBox
        self.acknowledgedState = mainThreadBox._current
    }

    public mutating func update() {
        // Move latest value from the subscription only when SwiftUI has requested an update.
        acknowledgedState = box._current
    }

    public func scoped<ScopedState, ScopedEvent>(
        to value: @escaping (State) -> ScopedState,
        event: @escaping (ScopedEvent) -> Event
    ) -> LoopBinding<ScopedState, ScopedEvent> {
        LoopBinding<ScopedState, ScopedEvent>(
            Loop(box: box.scoped(to: value, event: event))
        )
    }

    public func send(_ event: Event) {
        box.send(event)
    }
}

#endif
