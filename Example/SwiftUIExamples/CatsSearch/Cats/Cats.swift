import Foundation

enum Cats {
    private static let client: Connectable = {
       let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "x-api-key": "ff6f20f2-12a1-4f9e-a8a6-0062872c7fee"
        ]
        let session = URLSession(configuration: configuration)
        
        return HTTPClient(
            session: session,
            environment: Environment(schema: "https", host: "api.thecatapi.com")
        )
    }()
    
    static var breedsService: BreedsService {
        return DefaultBreedsService(connectable: client)
    }
    
    static var breedImageService: BreedImageService {
        return DefaultBreedImageService(connectable: client)
    }
}
