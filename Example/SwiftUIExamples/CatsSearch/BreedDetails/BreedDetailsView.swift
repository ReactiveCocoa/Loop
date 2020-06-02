import Loop
import SwiftUI

struct BreedDetailsView: View {
    @LoopBinding<BreedDetails.State, BreedDetails.Event>
    var state: BreedDetails.State
    @SwiftUI.Environment(\.imageFetcher)
    var fetcher
    
    init(binding: LoopBinding<BreedDetails.State, BreedDetails.Event>) {
        _state = binding
    }
    
    var body: some View {
        IfLetElseView(
            state.image,
            ifContent: render(image:),
            elseContent: {
                Spinner()
            }
        )
        .onAppear {
            self.$state.send(.startLoading)
        }
    }
    
    func render(image: BreedImage) -> some View {
        VStack {
            VStack {
                AsyncImage(source: fetcher.image(for: image.url).share().eraseToAnyPublisher()) {
                    Rectangle().fill(Color.gray)
                }
                .aspectRatio(CGSize(width: image.width, height: image.height), contentMode: .fit)
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Text(state.breed.name)
                            .font(.title)
                        Spacer()
                        Button(action: { self.$state.send(.didTapFavorite) }) {
                            Image(systemName: self.state.isFavorite ? "star.fill" : "star")
                        }
                    }
                    state.image.map { Text($0.id) }
                    state.breed.origin.map(Text.init)
                    state.breed.wikipediaUrl.map { it in
                        Button(action: {}) {
                            Text(it)
                        }
                    }
                }.padding([.trailing, .leading])
            }
            Spacer()
        }
    }
}

public struct IfLetElseView<Value, IfContent: View, ElseContent: View>: View {
    private let value: Value?
    private let ifContent: (Value) -> IfContent
    private let elseContent: () -> ElseContent
    
    public init(_ value: Value?,
                @ViewBuilder ifContent: @escaping (Value) -> IfContent,
                @ViewBuilder elseContent: @escaping () -> ElseContent) {
        self.value = value
        self.ifContent = ifContent
        self.elseContent = elseContent
    }
    
    public var body: some View {
        Group<_ConditionalContent<IfContent, ElseContent>> {
            if let value = value {
                return ViewBuilder.buildEither(first: self.ifContent(value))
            } else {
                return ViewBuilder.buildEither(second: self.elseContent())
            }
        }
    }
}
