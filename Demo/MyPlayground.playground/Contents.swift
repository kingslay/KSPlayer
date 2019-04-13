//: A UIKit based Playground for presenting user interface

import KSPlayer
import PlaygroundSupport
import UIKit
class ViewController: UIViewController {
    let playerView = IOSVideoPlayerView()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.readableContentGuide.topAnchor),
            playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        var url = URL(string: "http://wvideo./spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4")!
        url = URL(fileURLWithPath: Bundle.main.path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "MP4")!)
        playerView.set(url: url)
        playerView.play()
    }
}

// Present the view controller in the Live View window
PlaygroundPage.current.liveView = ViewController()
// let url = URL(fileURLWithPath: Bundle.main.path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "MP4")!)
// let playerLayer = KSPlayerLayer()
// playerLayer.set(url: url, options: nil)
// playerLayer.play()
// playerLayer.frame = UIScreen.main.bounds
// PlaygroundPage.current.liveView = playerLayer
