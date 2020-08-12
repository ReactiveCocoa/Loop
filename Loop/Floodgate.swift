import Foundation
import ReactiveSwift

final class Floodgate<State, Event>: FeedbackEventConsumer<Event> {
    struct QueueState {
        var events: [(Event, Token)] = []
        var isOuterLifetimeEnded = false

        var hasEvents: Bool {
            events.isEmpty == false && isOuterLifetimeEnded == false
        }
    }

    let (stateDidChange, changeObserver) = Signal<(State, Event?), Never>.pipe()

    /// Replay the current value, and then publish the subsequent changes.
    var producer: SignalProducer<State, Never> {
        return feedbackProducer.map(\.0)
    }
    
    private var feedbackProducer: SignalProducer<(State, Event?), Never> {
        SignalProducer { observer, lifetime in
            self.withValue { initial, hasStarted -> Void in
                observer.send(value: (initial, nil))
                lifetime += self.stateDidChange.observe(observer)
            }
        }
    }

    private let reducerLock = RecursiveLock()

    private var state: State
    private var hasStarted = false

    private let queue = Atomic(QueueState())
    private let reducer: (inout State, Event) -> Void
    private let feedbackDisposables = CompositeDisposable()

    init(state: State, reducer: @escaping (inout State, Event) -> Void) {
        self.state = state
        self.reducer = reducer
    }

    deinit {
        dispose()
    }

    func bootstrap(with feedbacks: [Loop<State, Event>.Feedback]) {
        for feedback in feedbacks {
            // Pass `producer` which has replay-1 semantic.
            feedbackDisposables += feedback.events(
                feedbackProducer,
                self
            )
        }

        processEnqueuedEvents()
    }

    override func process(_ event: Event, for token: Token) {
        enqueue(event, for: token)
        processEnqueuedEvents()
    }

    private func processEnqueuedEvents() {
        var continueToDrain = false

        repeat {
            // We use a recursive lock to guard the reducer, so as to allow state access via `withValue` to be
            // reentrant. But in order to not deadlock in ReactiveSwift, reentrant calls MUST NOT drain the queue.
            // Otherwise, `consume(_:)` will eventually invoke the reducer and send out a state via `changeObserver`,
            // leading to a deadlock.
            //
            // If we know that the call is reentrant, we can confidently skip draining the queue anyway, because the
            // outmost call — the one who first acquires the lock on the current lock owner thread — is already looping
            // to exhaustively drain the queue.
            continueToDrain = reducerLock.tryPerform { isReentrant in
                guard isReentrant == false else { return false }

                // Drain any recursively produced events.
                while let next = dequeue() {
                    reducer(&state, next)
                    changeObserver.send(value: (state, next))
                }

                return true
            }
        } while queue.withValue({ $0.hasEvents }) && continueToDrain
        // ^^^
        // Restart the event draining after we unlock the reducer lock, iff:
        //
        // 1. the queue still has unprocessed events; and
        // 2. no concurrent actor has taken the reducer lock, which implies no event draining would be started
        //    unless we take active action.
        //
        // This eliminates a race condition in the following sequence of operations:
        //
        // |              Thread A              |              Thread B              |
        // |------------------------------------|------------------------------------|
        // |     concurrent dequeue: no item    |                                    |
        // |                                    |         concurrent enqueue         |
        // |                                    |         trylock lock: BUSY         |
        // |            unlock lock             |                                    |
        // |                                    |                                    |
        // |             <<<  The enqueued event is left unprocessed. >>>            |
        //
        // The trylock-unlock duo has a synchronize-with relationship, which ensures that Thread A must see any
        // concurrent enqueue that *happens before* the trylock.
    }

    override func dequeueAllEvents(for token: Token) {
        queue.modify { $0.events.removeAll(where: { _, t in t == token }) }
    }

    func withValue<Result>(_ action: (State, Bool) -> Result) -> Result {
        let (result, isReentrant) = reducerLock.perform { isReentrant in
            (action(state, hasStarted), isReentrant)
        }

        // If the lock acquisition above is not reentrant, we are the lock owner, and events could be enqueued in
        // parallel during our brief ownership. So as the lock owner, we are obligated to defensively drain the event
        // queue here, even if we did not enqueue any event.
        //
        // If the lock acquisition is reentrant, it means someone else in the call stack is the lock owner. So we can
        // dodge this obligation.
        if isReentrant == false {
            processEnqueuedEvents()
        }

        return result
    }

    func dispose() {
        let shouldDisposeFeedbacks: Bool = queue.modify {
            let old = $0.isOuterLifetimeEnded
            $0.isOuterLifetimeEnded = true
            return old == false
        }

        if shouldDisposeFeedbacks {
            feedbackDisposables.dispose()
        }
    }

    private func enqueue(_ event: Event, for token: Token) {
        queue.modify { $0.events.append((event, token)) }
    }

    private func dequeue() -> Event? {
        queue.modify {
            guard $0.hasEvents else { return nil }
            return $0.events.removeFirst().0
        }
    }
}
