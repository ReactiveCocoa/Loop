import Combine
import SwiftUI

struct AsyncImage<PlaceHolder: View>: View {
    @State
    private var image: UIImage? = nil
    private let source: AnyPublisher<UIImage, Never>
    private let placeholder: () -> PlaceHolder

    init(
        source: AnyPublisher<UIImage, Never>,
        @ViewBuilder placeholder: @escaping () -> PlaceHolder
    ) {
        self.source = source
        self.placeholder = placeholder
    }

    var body: some View {
        IfLetElseView(
            self.$image.wrappedValue,
            ifContent: { i in
                Image(uiImage: i)
                    .resizable()
            },
            elseContent: placeholder
        )
        .onReceive(source.map(Optional.some)) { (image) in
            self.image = image
        }
    }
}

extension View {
    func bind<P: Publisher, Value>(
        _ publisher: P,
        to state: Binding<Value>
    ) -> some View where P.Failure == Never, P.Output == Value {
        return onReceive(publisher) { value in
            state.wrappedValue = value
        }
    }
}

class CombineImageFetcher {
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> AnyPublisher<UIImage, Never> {
        return Deferred { () -> AnyPublisher<UIImage, Never> in
            if let image = self.cache.object(forKey: url as NSURL) {
                print("Get cache: \(url)")
                return Result.Publisher(image)
                    .eraseToAnyPublisher()
            }

            return URLSession.shared
                .dataTaskPublisher(for: url)
                .map { $0.data }
                .compactMap(UIImage.init(data:))
                .handleEvents(receiveOutput: { image in
                    print("Set cache: \(url)")
                    self.cache.setObject(image, forKey: url as NSURL)
                })
                .catch { _ in
                    Empty()
                }
                .eraseToAnyPublisher()
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

struct ImageFetcherKey: EnvironmentKey {
    static let defaultValue = CombineImageFetcher()
}

extension EnvironmentValues {
    var imageFetcher: CombineImageFetcher {
        get {
            return self[ImageFetcherKey.self]
        }
        set {
            self[ImageFetcherKey.self] = newValue
        }
    }
}
