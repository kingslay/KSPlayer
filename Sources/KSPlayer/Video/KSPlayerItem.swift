//
//  KSPlayerItem.swift
//  Pods
//
//  Created by kintan on 16/5/21.
//
//

import AVFoundation
import Foundation
import MediaPlayer

public class KSPlayerResource: Equatable, Hashable {
    public static func == (lhs: KSPlayerResource, rhs: KSPlayerResource) -> Bool {
        lhs.definitions == rhs.definitions
    }

    public let name: String
    public let definitions: [KSPlayerResourceDefinition]
    public let cover: URL?
    public let subtitleDataSouce: SubtitleDataSouce?
    public var nowPlayingInfo: KSNowPlayableMetadata?
    public let extinf: [String: String]?
    /**
     Player recource item with url, used to play single difinition video

     - parameter name:      video name
     - parameter url:       video url
     - parameter cover:     video cover, will show before playing, and hide when play
     - parameter subtitleURLs: video subtitles
     */
    public convenience init(url: URL, options: KSOptions = KSOptions(), name: String = "", cover: URL? = nil, subtitleURLs: [URL]? = nil, extinf: [String: String]? = nil) {
        let definition = KSPlayerResourceDefinition(url: url, definition: "", options: options)
        let subtitleDataSouce: URLSubtitleDataSouce?
        if let subtitleURLs {
            subtitleDataSouce = URLSubtitleDataSouce(urls: subtitleURLs)
        } else {
            subtitleDataSouce = nil
        }

        self.init(name: name, definitions: [definition], cover: cover, subtitleDataSouce: subtitleDataSouce, extinf: extinf)
    }

    /**
     Play resouce with multi definitions

     - parameter name:        video name
     - parameter definitions: video definitions
     - parameter cover:       video cover
     - parameter subtitle:   video subtitle
     */
    public init(name: String, definitions: [KSPlayerResourceDefinition], cover: URL? = nil, subtitleDataSouce: SubtitleDataSouce? = nil, extinf: [String: String]? = nil) {
        self.name = name
        self.cover = cover
        self.subtitleDataSouce = subtitleDataSouce
        self.definitions = definitions
        self.extinf = extinf
        nowPlayingInfo = KSNowPlayableMetadata(title: name)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(definitions)
    }
}

extension KSPlayerResource: Identifiable {
    public var id: KSPlayerResource { self }
}

public struct KSPlayerResourceDefinition: Hashable {
    public static func == (lhs: KSPlayerResourceDefinition, rhs: KSPlayerResourceDefinition) -> Bool {
        lhs.url == rhs.url
    }

    public let url: URL
    public let definition: String
    public let options: KSOptions
    public init(url: URL) {
        self.init(url: url, definition: url.lastPathComponent)
    }

    /**
     Video recource item with defination name and specifying options

     - parameter url:        video url
     - parameter definition: url deifination
     - parameter options:    specifying options for the initialization of the AVURLAsset
     */
    public init(url: URL, definition: String, options: KSOptions = KSOptions()) {
        self.url = url
        self.definition = definition
        self.options = options
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

extension KSPlayerResourceDefinition: Identifiable {
    public var id: Self { self }
}

public struct KSNowPlayableMetadata {
    private let mediaType: MPNowPlayingInfoMediaType?
    private let isLiveStream: Bool?
    private let title: String
    private let artist: String?
    private let artwork: MPMediaItemArtwork?
    private let albumArtist: String?
    private let albumTitle: String?
    var nowPlayingInfo: [String: Any] {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = mediaType?.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = isLiveStream
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        if #available(OSX 10.13.2, *) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        nowPlayingInfo[MPMediaItemPropertyAlbumArtist] = albumArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
        return nowPlayingInfo
    }

    public init(mediaType: MPNowPlayingInfoMediaType? = nil, isLiveStream: Bool? = nil, title: String, artist: String? = nil,
                artwork: MPMediaItemArtwork? = nil, albumArtist: String? = nil, albumTitle: String? = nil)
    {
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
    }

    public init(mediaType: MPNowPlayingInfoMediaType? = nil, isLiveStream: Bool? = nil, title: String, artist: String? = nil, image: UIImage, albumArtist: String? = nil, albumTitle: String? = nil) {
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
        artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
