import Foundation
import ReactiveSwift

public protocol BreedImageService {
    func image(for breed: Breed) -> SignalProducer<BreedImage, CoreError>
}

public final class DefaultBreedImageService: BreedImageService {
    private let connectable: Connectable
    
    public init(connectable: Connectable) {
        self.connectable = connectable
    }
    
    public func image(for breed: Breed) -> SignalProducer<BreedImage, CoreError> {
        let resource = Resource<[BreedImage]>(
            path: "/v1/images/search",
            method: .GET,
            query: ["breed_id": breed.id.rawValue],
            response: Parser.convertFromSnakeCase.parse
        )
        return connectable.connect(to: resource).compactMap(\.first)
    }
}

public struct BreedImage: Decodable {
    public let id: String
    public let url: URL
    public let width: Double
    public let height: Double
    
    init(id: String, url: URL, width: Double, height: Double) {
        self.id = id
        self.url = url
        self.width = width
        self.height = height
    }
}
