import Loop
import ReactiveSwift
import SwiftUI

enum BreedDetails {
    struct State: Identifiable {
        var id: Breed.ID {
            return breed.id
        }
        
        let breed: Breed
        var image: BreedImage?
        var isFavorite = false
        var status: Status = .idle
        
        enum Status {
            case idle
            case loading
        }
    }
    
    enum Event {
        case startLoading
        case didTapFavorite
        case didLoadBreedImage(BreedImage)
        case didFail(CoreError)
    }
        
    public static var feedback: Loop<State, Event>.Feedback {
        return Self.whenLoading(service: Cats.breedImageService)
    }
    
    static func reducer(state: inout State, event: Event) {
        switch event {
        case .startLoading:
            state.status = state.image == nil ? .loading : .idle
        case .didTapFavorite:
            state.isFavorite.toggle()
        case .didFail:
            state.status = .idle
        case .didLoadBreedImage(let image):
            state.image = image
            state.status = .idle
        }
    }
    
    private static func whenLoading(service: BreedImageService) -> Loop<State, Event>.Feedback {
        .init { (state) -> SignalProducer<Event, Never> in
            guard case .loading = state.status else {
                return .empty
            }
            return service.image(for: state.breed)
                .map(Event.didLoadBreedImage)
                .replaceError(Event.didFail)
        }
    }
}
