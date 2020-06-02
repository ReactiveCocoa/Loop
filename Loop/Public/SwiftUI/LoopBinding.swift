import Combine
import ReactiveSwift
import SwiftUI

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
    internal var acknowledgedState: State!

    public init(_ loop: Loop<State, Event>) {
        // The subscription can be copied without restrictions.
        subscription = SwiftUISubscription()
        self.loop = loop
    }

    public mutating func update() {
        if subscription.hasStarted == false {
            subscription.attach(to: loop)
        }

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

    public func binding<U>(for keyPath: KeyPath<State, U>, event: Event) -> Binding<U> {
        return Binding(
            get: {
                self.wrappedValue[keyPath: keyPath]
            },
            set: { _ in
                self.send(event)
            }
        )
    }

    public func binding<U>(for keyPath: KeyPath<State, U>, event: @escaping (U) -> Event) -> Binding<U> {
        return Binding(
            get: {
                self.wrappedValue[keyPath: keyPath]
            },
            set: { value in
                self.send(event(value))
            }
        )
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct IfLetBinding<State, Action, IfContent: View, ElseContent: View>: View {
    public let binding: LoopBinding<State?, Action>
    public let ifContent: (LoopBinding<State, Action>) -> IfContent
    public let elseContent: () -> ElseContent

    /// Initializes a structure that safely unwraps loop bindings of optional state for views that depend on
    /// loop bindings of non-optional state.
    ///
    /// - Parameters:
    ///   - binding: A binding of optional state.
    ///   - ifContent: A function that is given a binding of non-optional state and returns a view that
    ///     is visible only when the optional state is non-`nil`.
    ///   - elseContent: A fall back function that returns a view when optional state is `nil`.
    public init(
        _ binding: LoopBinding<State?, Action>,
        then ifContent: @escaping (LoopBinding<State, Action>) -> IfContent,
        else elseContent: @escaping @autoclosure () -> ElseContent
    ) {
        self.binding = binding
        self.ifContent = ifContent
        self.elseContent = elseContent
    }

    public var body: some View {
        Group<_ConditionalContent<IfContent, ElseContent>> {
            if let state = binding.wrappedValue {
                return ViewBuilder.buildEither(
                    first: self.ifContent(
                        self.binding.scoped(
                            to: { $0 ?? state },
                            event: { $0 }
                        )
                    )
                )
            } else {
                return ViewBuilder.buildEither(second: self.elseContent())
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension IfLetBinding where ElseContent == EmptyView {
  /// Initializes a structure that safely unwraps loop bindings of optional state for views that depend on
  /// loop bindings of non-optional state.
  ///
  /// - Parameters:
  ///   - binding: A binding of optional state.
  ///   - ifContent: A function that is given a binding of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  public init(
    _ store: LoopBinding<State?, Action>,
    then ifContent: @escaping (LoopBinding<State, Action>) -> IfContent
  ) {
    self.init(store, then: ifContent, else: EmptyView())
  }
}
