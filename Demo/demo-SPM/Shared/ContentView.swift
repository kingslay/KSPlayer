//
//  ContentView.swift
//  Demo
//
//  Created by kintan on 2020/3/22.
//  Copyright © 2020 kintan. All rights reserved.
//

import KSPlayer
import SwiftUI

struct ContentView: View {
    @State private var resources = [KSPlayerResource]()
    var body: some View {
        NavigationView {
            MasterView(resources: $resources)
                .navigationBarTitle("m3u8")
                .navigationBarItems(trailing: Button(action: {
                    let alert = UIAlertController(title: "Input URL", message: nil, preferredStyle: .alert)
                    alert.addTextField { textField in
                        textField.placeholder = "play url"
                    }
                    alert.addTextField { textField in
                        textField.placeholder = "play list"
                    }
                    alert.addAction(UIAlertAction(title: "Done", style: .default) { _ in
                        if let text = alert.textFields?[0].text, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            let options = KSOptions()
                            if url.absoluteString.hasPrefix("rtmp") || url.absoluteString.hasPrefix("rtsp") {
                                options.formatContextOptions["timeout"] = 0
                            }
                            self.resources.insert(KSPlayerResource(url: url, options: options, name: "new add"), at: 0)
                        } else if let list = alert.textFields?[1].text {
                            self.updatem3u8(list.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    })
                    UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
                }) {
                    Image(systemName: "plus")
                })
        }.onAppear {
            self.loadCachem3u8()
            if self.resources.count == 0 {
                self.updatem3u8("https://iptv-org.github.io/iptv/countries/cn.m3u")
            }
        }
    }

    private func loadCachem3u8() {
        guard var path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        path.appendPathComponent("cache.m3u8")
        if FileManager.default.fileExists(atPath: path.path) {
            do {
                let data = try Data(contentsOf: path)
                guard let string = String(data: data, encoding: .utf8) else {
                    return
                }
                resources.removeAll()
                resources.append(contentsOf: parsem3u8(string: string))
            } catch {}
        }
    }

    private func updatem3u8(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let string = String(data: data, encoding: .utf8) else {
                return
            }
            self.saveToDocument(data: data, filename: "cache.m3u8")
            self.resources.removeAll()
            self.resources.append(contentsOf: self.parsem3u8(string: string))
        }.resume()
    }

    private func parsem3u8(string: String) -> [KSPlayerResource] {
        string.components(separatedBy: "#EXTINF:").compactMap { content in
            let array = content.split(separator: "\n")
            guard array.count > 1, let url = URL(string: String(array[1])) else {
                return nil
            }
            guard let name = array[0].split(separator: ",").last else {
                return nil
            }
            return KSPlayerResource(url: url, options: KSOptions(), name: String(name))
        }
    }

    private func saveToDocument(data: Data, filename: String) {
        guard var path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        path.appendPathComponent(filename)
        if FileManager.default.fileExists(atPath: path.absoluteString) {
            do {
                try FileManager.default.removeItem(at: path)
            } catch {}
        }
        do {
            try data.write(to: path)
        } catch {}
    }
}

struct MasterView: View {
    @Binding var resources: [KSPlayerResource]
    @State private var searchText = ""
    var body: some View {
        VStack {
            TextField("Search", text: $searchText)
            List {
                ForEach(resources.filter { $0.name.contains(searchText) || searchText.count == 0 }, id: \.self) { resource in
                    NavigationLink(resource.name, destination: StructPlayerView(resource: resource))
                }.onDelete { indices in
                    indices.forEach { self.resources.remove(at: $0) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#if !canImport(UIKit)
typealias UIViewRepresentable = NSViewRepresentable
#endif
struct StructPlayerView: UIViewRepresentable {
    var resource: KSPlayerResource
    #if canImport(UIKit)
    typealias UIViewType = VideoPlayerView
    func makeUIView(context _: Context) -> VideoPlayerView {
        VideoPlayerView()
    }

    func updateUIView(_ uiView: VideoPlayerView, context _: Context) {
        uiView.set(resource: resource)
    }
    #else
    typealias NSViewType = VideoPlayerView
    func makeNSView(context _: Context) -> VideoPlayerView {
        VideoPlayerView()
    }

    func updateNSView(_ nsView: VideoPlayerView, context _: Context) {
        nsView.set(resource: resource)
    }
    #endif
}
