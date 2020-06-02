import Foundation

public struct Parser<T> {
    public let parse: (Data, URLResponse) -> Result<T, Error>
    
    public init(parse: @escaping (Data, URLResponse) -> Result<T, Error>) {
        self.parse = parse
    }
}

extension Parser where T: Decodable {
    public static var convertFromSnakeCase: Parser {
        return Parser { (data, _) -> Result<T, Error> in
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            return Result {
                try decoder.decode(T.self, from: data)
            }
        }
    }
}
