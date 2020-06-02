public typealias Reducer<State, Event> = (inout State, Event) -> Void

public func combine<State, Event>(
    _ reducers: Reducer<State, Event>...
) -> Reducer<State, Event> {
    return { state, event in
        for reducer in reducers {
            reducer(&state, event)
        }
    }
}

public func pullback<LocalState, GlobalState, LocalEvent, GlobalEvent>(
    _ reducer: @escaping Reducer<LocalState, LocalEvent>,
    value: WritableKeyPath<GlobalState, LocalState>,
    extractEvent: @escaping (GlobalEvent) -> LocalEvent?
) -> Reducer<GlobalState, GlobalEvent> {
    return { globalState, globalEvent in
        guard let localEvent = extractEvent(globalEvent) else {
            return
        }
        reducer(&globalState[keyPath: value], localEvent)
    }
}

public func pullback<LocalState, GlobalState, LocalEvent, GlobalEvent>(
    _ reducer: @escaping Reducer<LocalState, LocalEvent>,
    value: WritableKeyPath<GlobalState, LocalState?>,
    extractEvent: @escaping (GlobalEvent) -> LocalEvent?
) -> Reducer<GlobalState, GlobalEvent> {
    return { globalState, globalEvent in
        guard let localEvent = extractEvent(globalEvent) else {
            return
        }
        if var copy = globalState[keyPath: value] {
            reducer(&copy, localEvent)
            globalState[keyPath: value] = copy
        }
    }
}
