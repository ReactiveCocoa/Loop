import ReactiveSwift

public protocol Connectable {
    func connect<T>(to resource: Resource<T>) -> SignalProducer<T, CoreError>
}

public final class HTTPClient: Connectable {
    private let session: URLSessionProtocol
    private let environment: Environment
    
    public init(session: URLSessionProtocol, environment: Environment) {
        self.session = session
        self.environment = environment
    }
    
    public func connect<T>(to resource: Resource<T>) -> SignalProducer<T, CoreError> {
        let request = resource.request(relativeTo: environment)
        return SignalProducer<(Data, URLResponse), NetworkError> { [session] (observer, lifetime) in
            let task = session.dataTask(with: request) { data, response, error in
                if let response = response as? HTTPURLResponse {
                    switch response.statusCode {
                    case 200..<300:
                        observer.send(value: (data ?? Data(), response))
                        observer.sendCompleted()
                    default:
                        observer.send(error: .server(statusCode: response.statusCode, data))
                    }
                } else if let error = error {
                    observer.send(error: .other(error))
                } else {
                    observer.send(error: .unknown)
                }
            }
            lifetime += AnyDisposable(task.cancel)
            task.resume()
        }
        .mapError(CoreError.network)
        .attemptMap { (data, response) in
            return resource.response(data, response).mapError(CoreError.parsing)
        }
    }
}

public protocol URLSessionProtocol {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask
}

extension URLSession: URLSessionProtocol {}

public enum NetworkError: Error {
    case other(Error)
    case server(statusCode: Int, Data?)
    case unknown
}

public enum CoreError: Error {
    case network(NetworkError)
    case parsing(Error)
}
