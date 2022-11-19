import KSPlayer
import SwiftUI
struct FirstView: View {
//    @Environment(\.dismiss) var dismiss

    @State private var showSecondView = false
    var body: some View {
        NavigationView {
            VStack {
                Text("Pretend this is a screen that the user selects which movie to view info on")
                    .padding(.bottom, 50)
                NavigationLink(destination: SecondView()) {
                    Text("Press To Show Info Screen")
                }
            }
        }
    }
}
