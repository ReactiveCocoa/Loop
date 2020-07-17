#if canImport(SwiftUI) && canImport(Combine)

import SwiftUI
import Combine
import ReactiveSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct LoopBinding<State, Event>: DynamicProperty {
    @ObservedObject
    private var subscription: SwiftUISubscription<State, Event>

    private let loop: Loop<State, Event>

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
        // The subscription can be copied without restrictions.
        let subscription = SwiftUISubscription(loop: loop)

        self.subscription = subscription
        self.acknowledgedState = subscription.latestValue
        self.loop = loop
    }

    public mutating func update() {
        // Move latest value from the subscription only when SwiftUI has requested an update.
        acknowledgedState = subscription.latestValue
    }

    public func scoped<ScopedState, ScopedEvent>(
        to value: @escaping (State) -> ScopedState,
        event: @escaping (ScopedEvent) -> Event
    ) -> LoopBinding<ScopedState, ScopedEvent> {
        LoopBinding<ScopedState, ScopedEvent>(loop.scoped(to: value, event: event))
    }

    public func send(_ event: Event) {
        loop.send(event)
    }
}

#endif
