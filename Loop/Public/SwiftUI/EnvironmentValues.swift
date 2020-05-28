#if canImport(SwiftUI)

import SwiftUI

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension View {
    @inlinable
    public func environmentLoop<State, Event>(_ loop: Loop<State, Event>) -> some View {
        let typeId = ObjectIdentifier(type(of: loop))

        return transformEnvironment(\.loops) { loops in
            loops[typeId] = loop
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EnvironmentValues {
    public var loops: [ObjectIdentifier: Any] {
        get { self[LoopEnvironmentKey.self] }
        set { self[LoopEnvironmentKey.self] = newValue }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal enum LoopEnvironmentKey: EnvironmentKey {
    static var defaultValue: [ObjectIdentifier: Any] {
        return [:]
    }
}

#endif
