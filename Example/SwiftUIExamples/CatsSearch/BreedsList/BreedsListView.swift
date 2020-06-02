import Loop
import SwiftUI
import UIKit

struct BreedsList: View {
    @LoopBinding<Breeds.State, Breeds.Event>
    var state: Breeds.State
    
    init(binding: LoopBinding<Breeds.State, Breeds.Event>) {
        _state = binding
    }
    
    var body: some View {
        List {
            if state.status == .loading {
                HStack {
                    Spinner()
                }
            }
            ForEach(state.detailsToShow) { details in
                TitleDetail(
                    title: details.breed.name,
                    detail: details.breed.origin ?? "",
                    isFavourite: details.isFavorite
                )
                .onTapGesture {
                    self.$state.send(.didSelectBreed(details))
                }
            }
        }
        .onAppear {
            self.$state.send(.refresh)
        }
        .navigationBarItems(
            trailing: Button(
                action: {
                    self.$state.send(.didTapShowFavorites)
                },
                label: {
                    Image(systemName: state.showFavorites ? "star.fill" : "star")
                }
            )
        )
        .sheet(item: self.$state.binding(for: \.selectedDetail, event: .sheetDismiss)) { _ in
            IfLetBinding(self.$state.scoped(
                to: \.selectedDetail,
                event: Breeds.Event.details
            ), then: BreedDetailsView.init)
        }
    }
}

struct TitleDetail: View {
    let title: String
    let detail: String
    let isFavourite: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(detail).font(.body)
            }
            Spacer()
            Image(systemName: isFavourite ? "star.fill" : "star")
        }
    }
}

struct Spinner: UIViewRepresentable {
    typealias UIViewType = UIActivityIndicatorView
    
    func makeUIView(context: UIViewRepresentableContext<Spinner>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView()
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<Spinner>) {
        uiView.startAnimating()
    }
}

struct TitleDetail_Previews: PreviewProvider {
    static var previews: some View {
        TitleDetail(title: "Hello", detail: "World", isFavourite: false)
    }
}

extension Int: Identifiable {
    public var id: Int {
        return self
    }
}
