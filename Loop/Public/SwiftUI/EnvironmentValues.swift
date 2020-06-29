#if canImport(SwiftUI)

import SwiftUI

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension View {
    @inlinable
    public func environmentLoop<State, Event>(_ loop: Loop<State, Event>) -> some View {
        let typeId = LoopType(type(of: loop))

        return transformEnvironment(\.loops) { loops in
            loops[typeId] = loop
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EnvironmentValues {
    @usableFromInline
    internal var loops: [LoopType: AnyObject] {
        get { self[LoopEnvironmentKey.self] }
        set { self[LoopEnvironmentKey.self] = newValue }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal enum LoopEnvironmentKey: EnvironmentKey {
    @usableFromInline
    static var defaultValue: [LoopType: AnyObject] {
        return [:]
    }
}

@usableFromInline
struct LoopType: Hashable {
    @usableFromInline
    let id: ObjectIdentifier

    @usableFromInline
    init(_ type: Any.Type) {
        id = ObjectIdentifier(type)
    }
}

#endif
