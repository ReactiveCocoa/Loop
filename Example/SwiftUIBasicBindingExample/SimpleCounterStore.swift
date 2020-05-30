import Loop

let simpleCounterStore = Loop(initial: 0, reducer: { state, event in state += event }, feedbacks: [])
