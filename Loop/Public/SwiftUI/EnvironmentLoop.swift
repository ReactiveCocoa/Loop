#if canImport(SwiftUI) && canImport(Combine)

import SwiftUI
import Combine
import ReactiveSwift

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct EnvironmentLoop<State, Event>: DynamicProperty {
    @Environment(\.loops[ObjectIdentifier(Loop<State, Event>.self)])
    var erasedLoop: Any?

    @ObservedObject
    private var subscription: SwiftUISubscription<State, Event>

    @inlinable
    public var wrappedValue: State {
        acknowledgedState
    }

    public var projectedValue: LoopBinding<State, Event> {
        guard let loop = erasedLoop as! Loop<State, Event>? else {
            fatalError("Scoped bindings can only be created inside the view body.")
        }

        return LoopBinding(loop)
    }

    @usableFromInline
    internal var acknowledgedState: State!

    public init() {
        self.subscription = SwiftUISubscription()
    }

    public mutating func update() {
        if isKnownUniquelyReferenced(&subscription) == false {
            subscription = SwiftUISubscription()
        }

        if subscription.hasStarted == false {
            guard let loop = erasedLoop as! Loop<State, Event>? else {
                fatalError("Expect parent view to inject a `Loop<\(State.self), \(Event.self)>` through `View.environmentLoop(_:)`. Found none.")
            }

            subscription.attach(to: loop)
        }

        acknowledgedState = subscription.latestValue
    }
}

#endif
