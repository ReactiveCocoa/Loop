import XCTest
import Nimble
import ReactiveSwift
@testable import Loop

class FeedbackVariantTests: XCTestCase {
    func test_whenBecomesTrue_positive_edge() {
        var receivedValues: [String] = []

        let loop = Loop<String, String>(
            initial: "",
            reducer: { content, string in
                content.append(contentsOf: string)
            },
            feedbacks: [
                .whenBecomesTrue(
                    { $0.hasSuffix("_") },
                    effects: { state -> SignalProducer<String, Never> in
                        receivedValues.append(state)

                        return SignalProducer(value: "feedback_")
                    }
                )
            ]
        )

        expect(loop.box._current) == ""

        loop.send("hello")
        expect(loop.box._current) == "hello"
        expect(receivedValues.last).to(beNil())

        // This should trigger a positive edge in `whenBecomesTrue`.
        loop.send("_")
        expect(loop.box._current) == "hello_feedback_"
        expect(receivedValues.last) == "hello_"

        // The predicate stays `true`, so no transition should occur.
        loop.send("_")
        expect(loop.box._current) == "hello_feedback__"
        expect(receivedValues.last) == "hello_"

        // This should lead to a negative edge.
        loop.send("world")
        expect(loop.box._current) == "hello_feedback__world"
        expect(receivedValues.last) == "hello_"

        // This should trigger a positive edge again in `whenBecomesTrue`.
        loop.send("_")
        expect(loop.box._current) == "hello_feedback__world_feedback_"
        expect(receivedValues.last) == "hello_feedback__world_"
    }

    func test_whenBecomesTrue_shouldFireEffectWhenInitialStateSatisfiesThePredicate() {
        var hasStarted = false
        var hasCancelled = false

        let loop = Loop<String, String>(
            initial: "hello",
            reducer: { content, string in
                content = string
            },
            feedbacks: [
                .whenBecomesTrue(
                    { $0.hasPrefix("hello") },
                    effects: { _ in
                        SignalProducer.never
                            .on(started: { hasStarted = true })
                            .on(disposed: { hasCancelled = true })
                    }
                )
            ]
        )

        expect(hasStarted) == true
        expect(hasCancelled) == false

        loop.send("")
        expect(hasCancelled) == true
    }

    func test_whenBecomesTrue_negative_edge() {
        var hasStarted = false
        var hasCancelled = false

        let loop = Loop<String, String>(
            initial: "",
            reducer: { content, string in
                content.append(contentsOf: string)
            },
            feedbacks: [
                .whenBecomesTrue(
                    { $0.hasSuffix("_") },
                    effects: { _ in
                        SignalProducer.never
                            .on(started: { hasStarted = true })
                            .on(disposed: { hasCancelled = true })
                    }
                )
            ]
        )

        expect(loop.box._current) == ""
        expect(hasStarted) == false

        // This should trigger a positive edge in `whenBecomesTrue`.
        loop.send("_")
        expect(hasStarted) == true
        expect(hasCancelled) == false

        loop.send("_")
        expect(hasCancelled) == false

        loop.send("_")
        expect(hasCancelled) == false

        // This should lead to a negative edge, which in turn should cancel the effect.
        loop.send("word")
        expect(hasCancelled) == true
    }

    func test_firstValueAfterNil_positive_edge() {
        var receivedValues: [String] = []

        let loop = Loop<String, String>(
            initial: "",
            reducer: { content, string in
                content = string
            },
            feedbacks: [
                .firstValueAfterNil(
                    { $0.hasPrefix("hello") ? $0 : nil },
                    effects: { state -> SignalProducer<String, Never> in
                        receivedValues.append(state)

                        return SignalProducer(value: "\(String(repeating: state, count: 2))")
                    }
                )
            ]
        )

        expect(loop.box._current) == ""
        expect(receivedValues.last).to(beNil())

        // This should trigger a positive edge in `firstValueAfterNil`.
        loop.send("hello#")
        expect(loop.box._current) == "hello#hello#"
        expect(receivedValues.last) == "hello#"

        // The transform output stays non-nil, so no transition should occur.
        loop.send("hello_world")
        expect(loop.box._current) == "hello_world"
        expect(receivedValues.last) == "hello#"

        // This should lead to a negative edge.
        loop.send("goodbye")
        expect(loop.box._current) == "goodbye"
        expect(receivedValues.last) == "hello#"

        // This should trigger a positive edge again in `firstValueAfterNil`.
        loop.send("hello_it_is_me#")
        expect(loop.box._current) == "hello_it_is_me#hello_it_is_me#"
        expect(receivedValues.last) == "hello_it_is_me#"
    }

    func test_firstValueAfterNil_shouldFireEffectWhenInitialStateGivesNonNilTransformOutput() {
        var hasStarted = false
        var hasCancelled = false

        let loop = Loop<String, String>(
            initial: "hello",
            reducer: { content, string in
                content = string
            },
            feedbacks: [
                .firstValueAfterNil(
                    { $0.hasPrefix("hello") ? $0 : nil },
                    effects: { _ in
                        SignalProducer.never
                            .on(started: { hasStarted = true })
                            .on(disposed: { hasCancelled = true })
                    }
                )
            ]
        )

        expect(hasStarted) == true
        expect(hasCancelled) == false

        loop.send("")
        expect(hasCancelled) == true
    }

    func test_firstValueAfterNil_negative_edge() {
        var hasStarted = false
        var hasCancelled = false

        let loop = Loop<String, String>(
            initial: "",
            reducer: { content, string in
                content = string
            },
            feedbacks: [
                .firstValueAfterNil(
                    { $0.hasPrefix("hello") ? $0 : nil },
                    effects: { _ in
                        SignalProducer.never
                            .on(started: { hasStarted = true })
                            .on(disposed: { hasCancelled = true })
                    }
                )
            ]
        )

        expect(loop.box._current) == ""
        expect(hasStarted) == false

        // This should trigger a positive edge in `whenBecomesTrue`.
        loop.send("hello1")
        expect(hasStarted) == true
        expect(hasCancelled) == false

        loop.send("hello2")
        expect(hasCancelled) == false

        loop.send("hello3")
        expect(hasCancelled) == false

        // This should lead to a negative edge, which in turn should cancel the effect.
        loop.send("world")
        expect(hasCancelled) == true
    }

    func test_autoconnect_disposes_and_restores_flows_according_to_predicate() {

        let loop = Loop<String, String>(
            initial: "",
            reducer: { content, string in
                content = string
            },
            feedbacks: [
                Loop<String, String>.Feedback
                    .init(
                        lensing: { $0.hasPrefix("hello") ? $0 : nil },
                        effects: { SignalProducer(value: $0.uppercased()) }
                    )
                    .autoconnect(followingChangesIn: { $0.contains("disconnect") == false })
            ]
        )

        expect(loop.box._current) == ""

        // This should trigger an uppercased event
        loop.send("hello1")
        expect(loop.box._current) == "HELLO1"

        loop.send("hello2")
        expect(loop.box._current) == "HELLO2"

        // This should lead to feedabck "disconnection", which in turn should cancel and disable the uppercasing effect.
        loop.send("hello disconnect")
        expect(loop.box._current) == "hello disconnect"

        // This should lead feedback "connection", which in turn should reestablish the uppercasing effect.
        loop.send("hello3")
        expect(loop.box._current) == "HELLO3"
    }
}
