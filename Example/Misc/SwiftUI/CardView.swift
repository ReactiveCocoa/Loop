import SwiftUI

struct CardNavigationLink<Destination: View>: View {
    let label: String
    let color: Color
    let destination: Destination

    @State var canAnimate: Bool = false
    @State var isTouchedDown: Bool = false

    init(label: String, color: Color, @ViewBuilder destination: () -> Destination) {
        self.label = label
        self.color = color
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(
            destination: destination,
            label: {
                Text(label)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        )
        .buttonStyle(CardButtonStyle(color: color))
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScrollView {
                CardNavigationLink(label: "Single Store + UIKit", color: .blue) {
                    EmptyView()
                }
            }
        }
    }
}

struct CardButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                configuration.label
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(16)
        .background(
            GeometryReader { proxy in
                RadialGradient(
                    gradient: Gradient(colors: [self.color, self.color.opacity(0.5)]),
                    center: UnitPoint(x: 0.9, y: 0.9),
                    startRadius: proxy.size.height * 1.75,
                    endRadius: proxy.size.height * 0.4
                )
            }
        )
        .cornerRadius(20)
        .shadow(color: Color.gray, radius: 16)
        .padding(16)
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .frame(maxWidth: .infinity)
        .animation(.spring(), value: configuration.isPressed)
    }
}
