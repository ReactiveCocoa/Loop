#if canImport(SwiftUI) && canImport(Combine)

import SwiftUI
import Combine
import ReactiveSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct EnvironmentLoop<State, Event>: DynamicProperty {
    static var loopType: LoopType { LoopType(Loop<State, Event>.self) }

    @Environment(\.loops)
    var erasedLoops: [LoopType: AnyObject]

    @ObservedObject
    private var subscription: SwiftUIHotSwappableSubscription<State, Event>

    var injectedLoop: Loop<State, Event> {
        let key = LoopType(Loop<State, Event>.self)
        guard let injected = erasedLoops[key] as! Loop<State, Event>? else {
            fatalError("""
            Expected a `Loop<\(State.self), \(Event.self)>` has been injected by `View.environmentLoop(_:)`. Found none.
            """)
        }

        return injected
    }

    @inlinable
    public var wrappedValue: State {
        acknowledgedState
    }

    public var projectedValue: LoopBinding<State, Event> {
        return LoopBinding(injectedLoop)
    }

    @usableFromInline
    internal var acknowledgedState: State!

    public init() {
        self.subscription = SwiftUIHotSwappableSubscription()
    }

    public mutating func update() {
        acknowledgedState = subscription.currentState(in: injectedLoop)
    }
}

#endif
