import Foundation
// Objc.io Resource
public struct Resource<Response> {
    public typealias Headers = [String: String]
    public typealias Query = [String: String]
    public let path: String
    public let method: Method
    public let headers: Headers
    public let query: Query?
    public let response: (Data, URLResponse) -> Result<Response, Error>

    public init(
        path: String = "",
        method: Method = .GET,
        headers: Headers = [:],
        query: Query? = nil,
        response: @escaping (Data, URLResponse) -> Result<Response, Error>
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.query = query
        self.response = response
    }

    public var description: String {
        return "Path:\(self.path)\nMethod:\(self.method.rawValue)\nHeaders:\(self.headers)"
    }

    public func request(relativeTo environment: Environment) -> URLRequest {
        var components = URLComponents()
        
        components.scheme = environment.schema
        components.host = environment.host
        components.path = path
        components.queryItems = query?.map { (key, value) in
            URLQueryItem(name: key, value: value)
        }
        
        var request = URLRequest(url: components.url!)
        
        request.allHTTPHeaderFields = headers
        request.httpMethod = method.rawValue
        
        return request
    }
}

public struct Environment {
    let schema: String
    let host: String
    
    public init(schema: String, host: String) {
        self.schema = schema
        self.host = host
    }
}

public enum Method: String {
    case OPTIONS
    case GET
    case HEAD
    case POST
    case PUT
    case PATCH
    case DELETE
    case TRACE
    case CONNECT
}

extension URLComponents {
    mutating func setQueryItems(with parameters: [String: String]) {
        self.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
}
