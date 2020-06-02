import Foundation
import ReactiveSwift

public protocol BreedsService {
    func fetch() -> SignalProducer<[Breed], CoreError>
    func query(name: String) -> SignalProducer<[Breed], CoreError>
}

public final class DefaultBreedsService: BreedsService {
    private let connectable: Connectable
    
    public init(connectable: Connectable) {
        self.connectable = connectable
    }
    
    public func fetch() -> SignalProducer<[Breed], CoreError> {
        let resource = Resource<[Breed]>(
            path: "/v1/breeds",
            method: .GET,
            response: Parser.convertFromSnakeCase.parse
        )
        return connectable.connect(to: resource)
    }
    
    public func query(name: String) -> SignalProducer<[Breed], CoreError> {
        // Query probably should be encoded with URLQueryItem ¯\_(ツ)_/¯
        let resource = Resource<[Breed]>(
            path: "/v1/breeds/search",
            method: .GET,
            query: ["q": name],
            response: Parser.convertFromSnakeCase.parse
        )
        return connectable.connect(to: resource)
    }
}

public struct Breed: Decodable, Identifiable, Equatable {
    public let id: ID
    public let name: String
    public let temperament: String?
    public let lifeSpan: String?
    public let wikipediaUrl: String?
    public let origin: String?
    
    public init(
        id: ID,
        name: String,
        temperament: String,
        lifeSpan: String,
        wikipediaUrl: String?,
        origin: String
    ) {
        self.id = id
        self.name = name
        self.temperament = temperament
        self.lifeSpan = lifeSpan
        self.wikipediaUrl = wikipediaUrl
        self.origin = origin
    }
}

public struct ID: Hashable, Decodable, Encodable, Identifiable {
    public let rawValue: String
    
    public var id: String {
        return rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            rawValue = String(try container.decode(Int.self))
        } catch _ {
            rawValue = try container.decode(String.self)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

