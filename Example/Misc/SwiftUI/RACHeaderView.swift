import SwiftUI

struct RACHeaderView: View {
    var body: some View {
        VStack(spacing: 0.0) {
            Image("ReactiveCocoa")
                .resizable()
                .antialiased(true)
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 150)
            Text("Loop")
                .foregroundColor(Color("racTertiary"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .offset(x: 0, y: -20)
        }
    }
}

struct RACHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        RACHeaderView()
    }
}
