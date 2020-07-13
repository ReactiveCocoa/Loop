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

    @inlinable
    public var wrappedValue: State {
        acknowledgedState
    }

    public var projectedValue: LoopBinding<State, Event> {
        guard let loop = erasedLoops[Self.loopType] as! Loop<State, Event>? else {
            fatalError("Scoped bindings can only be created inside the view body.")
        }

        return LoopBinding(loop)
    }

    @usableFromInline
    internal var acknowledgedState: State!

    public init() {
        self.subscription = SwiftUIHotSwappableSubscription()
    }

    public mutating func update() {
        guard let loop = erasedLoops[Self.loopType] as! Loop<State, Event>? else {
            fatalError("Expect parent view to inject a `Loop<\(State.self), \(Event.self)>` through `View.environmentLoop(_:)`. Found none.")
        }

        acknowledgedState = subscription.currentState(in: loop)
    }
}

#endif
