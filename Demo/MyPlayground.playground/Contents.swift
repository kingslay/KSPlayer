//: A UIKit based Playground for presenting user interface

import KSPlayer
import PlaygroundSupport
import UIKit
class ViewController: UIViewController {
    var player = VideoPlayerController()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(player.view)
        player.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            player.view.topAnchor.constraint(equalTo: view.readableContentGuide.topAnchor),
            player.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            player.view.rightAnchor.constraint(equalTo: view.rightAnchor),
            player.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        view.layoutIfNeeded()
        var url = URL(string: "http://wvideo./spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4")!
        url = URL(fileURLWithPath: Bundle.main.path(forResource: "567082ac3ae39699f68de4fd2b7444b1e045515a", ofType: "MP4")!)
        player.set(url: url)
        player.play()
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
