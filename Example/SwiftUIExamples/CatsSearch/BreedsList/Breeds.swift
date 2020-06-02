import Loop
import ReactiveSwift
import SwiftUI

enum Breeds {
    struct State {
        fileprivate var breeds: [BreedDetails.State] = []
        var showFavorites = false
        var status: Status = .idle
        
        var selectedDetail: BreedDetails.State? {
            didSet {
                if let selectedDetail = selectedDetail, let index = breeds.firstIndex(where: { $0.breed == selectedDetail.breed }) {
                    breeds[index] = selectedDetail
                }
            }
        }
        
        var detailsToShow: [BreedDetails.State] {
            return showFavorites ? breeds.filter(\.isFavorite) : breeds
        }
                
        enum Status {
            case idle
            case loading
        }
        
        struct Selection {
            var index: Int
            var details: BreedDetails.State
        }
    }
    
    enum Event {
        case sheetDismiss
        case didSelectBreed(BreedDetails.State)
        case didLoadBreeds([Breed])
        case didFail(CoreError)
        case refresh
        case details(BreedDetails.Event)
        case didTapShowFavorites
        
        var details: BreedDetails.Event? {
            switch self {
            case .details(let event):
                return event
            default:
                return nil
            }
        }
    }
    
    static func makeCatsView() -> some View {
        return BreedsList(binding: makeLoop(breedsService: Cats.breedsService).binding)
            .navigationBarTitle("Cats")
    }
    
    static func makeLoop(breedsService: BreedsService) -> Loop<State, Event> {
        let path = \Breeds.State.selectedDetail
        return Loop(
            initial: State(),
            reducer: combine(
                reducer,
                pullback(
                    BreedDetails.reducer(state:event:),
                    value: path,
                    extractEvent: \.details
                )
            ),
            feedbacks: [
                whenLoading(breedsService: breedsService),
                BreedDetails.feedback.pullback(
                    value: path,
                    embedEvent: Event.details
                )
            ]
        )
    }
    
    static func reducer(state: inout State, event: Event) {
        switch event {
        case .didLoadBreeds(let breeds):
            state.breeds = breeds.map {
                BreedDetails.State(breed: $0)
            }
            state.status = .idle
        case .didFail:
            state.status = .idle
        case .refresh:
            state.status = .loading
        case .sheetDismiss:
            state.selectedDetail = nil
        case .didSelectBreed(let detail):
            state.selectedDetail = detail
        case .didTapShowFavorites:
            state.showFavorites.toggle()
        case .details:
            break
        }
    }
    
    private static func whenLoading(breedsService: BreedsService) -> Loop<State, Event>.Feedback {
        .init { (state) -> SignalProducer<Event, Never> in
            guard case .loading = state.status else {
                return .empty
            }
            return breedsService.fetch()
                .map(Event.didLoadBreeds)
                .replaceError(Event.didFail)
        }
    }
}
