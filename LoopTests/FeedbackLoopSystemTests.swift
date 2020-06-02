import XCTest
import Nimble
import ReactiveSwift
@testable import Loop

class FeedbackLoopSystemTests: XCTestCase {

    func test_emits_initial() {
        let initial = "initial"
        let feedback = Loop<String, String>.Feedback { state in
            return SignalProducer(value: "_a")
        }
        let system = SignalProducer<String, Never>.feedbackLoop(
            initial: initial,
            reduce: { (state, event) in
                state += event
            },
            feedbacks: feedback)
        let result = ((try? system.first()?.get()) as String??)

        expect(result) == initial
    }

    func test_reducer_with_one_feedback_loop() {
        let feedback = Loop<String, String>.Feedback { state in
            return SignalProducer(value: "_a")
        }
        let system = SignalProducer<String, Never>.feedbackLoop(
            initial: "initial",
            reduce: { (state, event) in
                state += event
            },
            feedbacks: feedback)

        var result: [String]!
        system.take(first: 3)
            .collect()
            .startWithValues {
                result = $0
            }

        let expected = [
            "initial",
            "initial_a",
            "initial_a_a"
        ]
        expect(result).toEventually(equal(expected))
    }

    func test_reduce_with_two_immediate_feedback_loops() {
        let feedback1 = Loop<String, String>.Feedback { state in
            return !state.hasSuffix("_a") ? SignalProducer(value: "_a") : .empty
        }
        let feedback2 = Loop<String, String>.Feedback { state in
            return !state.hasSuffix("_b") ? SignalProducer(value: "_b") : .empty
        }
        let system = SignalProducer<String, Never>.feedbackLoop(
            initial: "initial",
            reduce: { (state, event) in
                state += event
            },
            feedbacks: feedback1, feedback2
        )

        var result: [String]!
        system.take(first: 5)
            .collect()
            .startWithValues {
                result = $0
            }

        let expected = [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_a",
            "initial_a_b_a_b",
        ]
        expect(result).toEventually(equal(expected))
    }

    func test_reduce_with_async_feedback_loop() {
        let feedback = Loop<String, String>.Feedback { state -> SignalProducer<String, Never> in
            if state == "initial" {
                return SignalProducer(value: "_a")
                    .delay(0.1, on: QueueScheduler.main)
            }
            if state == "initial_a" {
                return SignalProducer(value: "_b")
            }
            if state == "initial_a_b" {
                return SignalProducer(value: "_c")
            }
            return SignalProducer.empty
        }
        let system = SignalProducer<String, Never>.feedbackLoop(
            initial: "initial",
            reduce: { (state, event) in
                state += event
            },
            feedbacks: feedback)

        var result: [String]!
        system.take(first: 4)
            .collect()
            .startWithValues {
                result = $0
            }

        let expected = [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_c"
        ]
        expect(result).toEventually(equal(expected))
    }

    func test_should_observe_signals_immediately() {
        let (signal, observer) = Signal<String, Never>.pipe()

        let system = SignalProducer<String, Never>.feedbackLoop(
            initial: "initial",
            reduce: { (state, event) in
                state += event
            },
            feedbacks: [
                Loop<String, String>.Feedback { state in
                    return signal.producer
                }
            ]
        )

        var value: String?
        system.startWithValues { value = $0 }

        expect(value) == "initial"

        observer.send(value: "_a")
        expect(value) == "initial_a"
    }

    func test_should_start_producers_immediately() {
        var startCount = 0

        let system = SignalProducer<String, Never>.feedbackLoop(
            initial: "initial",
            reduce: { (state, event) in
                state += event
            },
            feedbacks: [
                Loop<String, String>.Feedback { state -> SignalProducer<String, Never> in
                    return SignalProducer(value: "_a")
                        .on(starting: { startCount += 1 })
                }
            ]
        )

        var values: [String] = []
        system
            .skipRepeats()
            .take(first: 3)
            .startWithValues { values.append($0) }

        expect(values) == ["initial", "initial_a", "initial_a_a"]
        expect(startCount) == 2
    }

    func test_should_not_miss_delivery_to_reducer_when_started_asynchronously() {
        let creationScheduler = QueueScheduler()

        let observedState: Atomic<[String]> = Atomic([])

        let semaphore = DispatchSemaphore(value: 0)

        creationScheduler.schedule {
             SignalProducer<String, Never>
                .feedbackLoop(
                    initial: "initial",
                    reduce: { (state, event) in
                        state += event
                    },
                    feedbacks: [
                        Loop<String, String>.Feedback { state, output in
                            state
                                .take(first: 1)
                                .map(value: "_event")
                                .on(terminated: { semaphore.signal() })
                                .enqueue(to: output)
                        }
                    ]
                )
                .startWithValues { state in
                    observedState.modify { $0.append(state) }
                }
        }

        semaphore.wait()
        expect(observedState.value).toEventually(equal(["initial", "initial_event"]))
    }

    func test_predicate_prevents_state_updates() {
        enum Event {
            case increment
        }
        let (incrementSignal, incrementObserver) = Signal<Void, Never>.pipe()
        let feedback = Loop<Int, Event>.Feedback(predicate: { $0 < 2 }) { _ in
            incrementSignal.map { _ in Event.increment }
        }
        let system = SignalProducer<Int, Never>.feedbackLoop(
            initial: 0,
            reduce: { (state, event) in
                switch event {
                case .increment:
                    state += 1
                }
            },
            feedbacks: [feedback])

        let (lifetime, token) = Lifetime.make()

        var result: [Int]!
        system.take(during: lifetime)
            .collect()
            .startWithValues {
                result = $0
            }

        func increment(numberOfTimes: Int) {
            guard numberOfTimes > 0 else {
                DispatchQueue.main.async { token.dispose() }
                return
            }
            DispatchQueue.main.async {
                incrementObserver.send(value: ())
                increment(numberOfTimes: numberOfTimes - 1)
            }
        }
        increment(numberOfTimes: 7)

        let expected = [0, 1, 2]

        expect(result).toEventually(equal(expected))
    }

    func test_external_source_events_are_not_cancelled_when_source_completes() {
        enum Event {
            case increment(by: Int)
            case timeConsumingWork
        }

        let semaphore = DispatchSemaphore(value: 0)

        let (increments, incrementObserver) = Signal<Int, Never>.pipe()
        let (workTrigger, workTriggerObserver) = Signal<Void, Never>.pipe()

        let system = SignalProducer<Int, Never>.feedbackLoop(
            initial: 0,
            reduce: { (state, event) in
                switch event {
                case let .increment(steps):
                    state += steps

                case .timeConsumingWork:
                    semaphore.wait()
                }
            },
            feedbacks: [
                Loop.Feedback(source: increments, as: Event.increment(by:)),
                Loop.Feedback(source: workTrigger, as: { .timeConsumingWork })
            ]
        )

        var results: [Int] = []

        system.startWithValues { value in
            results.append(value)
        }

        expect(results) == [0]

        incrementObserver.send(value: 1)
        incrementObserver.send(value: 2)
        incrementObserver.send(value: 3)
        expect(results) == [0, 1, 3, 6]

        waitUntil { done in
            DispatchQueue.global(qos: .userInteractive).async {
                done()
                workTriggerObserver.send(value: ())
            }
        }

        // Sleep for 500us so that we continue the assertions after `workTriggerObserver.send(value: ())` is invoked.
        usleep(500)

        incrementObserver.send(value: 1)
        incrementObserver.send(value: 2)
        incrementObserver.send(value: 3)
        incrementObserver.sendCompleted()

        // Allow the reducer running in background to proceed.
        semaphore.signal()

        expect(results).toEventually(equal([0, 1, 3, 6, 6, 7, 9, 12]))
    }

    func test_feedback_state_producer_replays_latest_value() {
        let system = SignalProducer<Int, Never>.feedbackLoop(
            initial: 0,
            reduce: { (state: inout Int, event: Int) in
                state += event
            },
            feedbacks: [
                Loop.Feedback { state, output in
                    state
                        .take(first: 1)
                        .then(SignalProducer(value: 2))
                        .concat(
                            // `state` is NOT GUARANTEED to reflect events emitted earlier in the producer chain.
                            state
                                .take(first: 3)
                                .map(\.0)
                                .map { $0 + 1000 }
                        )
                        .enqueue(to: output)
                }
            ]
        )

        var results: [Int] = []

        system.startWithValues { value in
            results.append(value)
        }

        expect(results) == [0, 2, 1002, 2004, 4006]
    }
    
    func test_events_are_produced_in_correct_order() {
        let (feedback, input) = Loop<Int, Int>.Feedback.input
        var events: [Int] = []
        let system = SignalProducer<Int, Never>.feedbackLoop(
            initial: 0,
            reduce: { (state: inout Int, event: Int) in
                events.append(event)
                state += event
            },
            feedbacks: [
                feedback
            ]
        )

        var results: [Int] = []

        system.startWithValues { value in
            results.append(value)
        }
        
        input(1)
        input(2)
        input(3)

        expect(results) == [0, 1, 3, 6]
        expect(events) == [1, 2, 3]
    }
}
