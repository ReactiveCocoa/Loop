import Loop
import ReactiveSwift
import UIKit

enum UnifiedStore {
    static let store = Loop(
        initial: State(),
        reducer: reducer,
        feedbacks: [feedbacks]
    )

    private static let reducer: Reducer<State, Event> = combine(
        pullback(
            Counter.reduce,
            value: \.counter,
            event: \.counter
        ),
        pullback(
            Movies.reduce,
            value: \.movies,
            event: \.movies
        )
    )

    private static let feedbacks: Loop<State, Event>.Feedback = Movies.feedback
        .pullback(
            value: \.movies,
            embedEvent: Event.movies,
            extractEvent: { (event) -> Movies.Event? in
                switch event {
                case let .movies(moviesEvent):
                    return moviesEvent
                default:
                    return nil
                }
            }
        )
}

extension UnifiedStore {
    struct State {
        var counter = Counter.State()
        var movies = Movies.State()
    }

    enum Event {
        case counter(Counter.Event)
        case movies(Movies.Event)

        // This can be done with CasePaths
        // https://github.com/pointfreeco/swift-case-paths
        var counter: Counter.Event? {
            get {
                guard case let .counter(value) = self else { return nil }
                return value
            }
            set {
                guard case .counter = self, let newValue = newValue else { return }
                self = .counter(newValue)
            }
        }

        var movies: Movies.Event? {
            get {
                guard case let .movies(value) = self else { return nil }
                return value
            }
            set {
                guard case .movies = self, let newValue = newValue else { return }
                self = .movies(newValue)
            }
        }
    }
}
