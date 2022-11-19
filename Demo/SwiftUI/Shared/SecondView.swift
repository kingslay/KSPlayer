
import KSPlayer
import SwiftUI

struct SecondView: View {
//    // the fact this line is in here, means that it interferes with KSPlayer
    @Environment(\.dismiss) var dismiss

    // I need the dismiss option because I have a sheet that apears asking the user to enter their parental control passcode
    @State var playVideo = false
    let myOptions = KSOptions()
    init() {
        myOptions.isAutoPlay = true
        myOptions.autoSelectEmbedSubtitle = false
        KSOptions.firstPlayerType = KSMEPlayer.self
    }

    var body: some View {
        VStack {
            Text("Pretend this is the movie information screen")
                .padding(.bottom, 50)
            ThirdView()
                .padding(.bottom, 50)
            Button {
                playVideo = true
            } label: {
                Text("Play Movie Via .fullScreenCover")
            }
            .padding(.bottom, 50)
        }.fullScreenCover(isPresented: $playVideo) {
            KSVideoPlayerView(url: URL(fileURLWithPath: Bundle.main.path(forResource: "h264", ofType: "mp4")!), options: KSOptions())
        }
    }
}

struct ThirdView: View {
    var body: some View {
        NavigationLink(destination: KSVideoPlayerView(url: URL(fileURLWithPath: Bundle.main.path(forResource: "h264", ofType: "mp4")!), options: KSOptions())) {
            Text("Play Movie")
        }
    }
}
