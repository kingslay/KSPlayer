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

public class KSPlayerResource: Hashable {
    public static func == (lhs: KSPlayerResource, rhs: KSPlayerResource) -> Bool {
        lhs.definitions == rhs.definitions
    }

    public let name: String
    public let cover: URL?
    public let definitions: [KSPlayerResourceDefinition]
    public var subtitle: KSSubtitleProtocol?
    public var nowPlayingInfo: KSNowPlayableMetadata?
    /**
     Player recource item with url, used to play single difinition video

     - parameter name:      video name
     - parameter url:       video url
     - parameter cover:     video cover, will show before playing, and hide when play
     - parameter subtitleURL: video subtitle
     */
    public convenience init(url: URL, options: KSOptions = KSOptions(), name: String = "", cover: URL? = nil, subtitleURL: URL? = nil) {
        let definition = KSPlayerResourceDefinition(url: url, definition: "", options: options)
        var subtitle: KSSubtitleProtocol?
        if let subtitleURL = subtitleURL {
            subtitle = KSURLSubtitle(url: subtitleURL)
        }
        self.init(name: name, definitions: [definition], cover: cover, subtitle: subtitle)
    }

    /**
     Play resouce with multi definitions

     - parameter name:        video name
     - parameter definitions: video definitions
     - parameter cover:       video cover
     - parameter subtitle:   video subtitle
     */
    public init(name: String = "", definitions: [KSPlayerResourceDefinition], cover: URL? = nil, subtitle: KSSubtitleProtocol? = nil) {
        self.name = name
        self.cover = cover
        self.subtitle = subtitle
        self.definitions = definitions
        nowPlayingInfo = KSNowPlayableMetadata(title: name)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(definitions)
    }
}

public class KSPlayerResourceDefinition: Hashable {
    public static func == (lhs: KSPlayerResourceDefinition, rhs: KSPlayerResourceDefinition) -> Bool {
        lhs.url == rhs.url
    }

    public let url: URL
    public let definition: String
    public let options: KSOptions

    /**
     Video recource item with defination name and specifying options

     - parameter url:        video url
     - parameter definition: url deifination
     - parameter options:    specifying options for the initialization of the AVURLAsset

     you can add http-header or other options which mentions in https://developer.apple.com/reference/avfoundation/avurlasset/initialization_options

     to add http-header init options like this
     ```
     let header = ["user_agent":"KSPlayer"]
     let options = KSOptions()
     options.avOptions = ["AVURLAssetHTTPHeaderFieldsKey":header]
     ```
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

    init(mediaType: MPNowPlayingInfoMediaType? = nil, isLiveStream: Bool? = nil, title: String, artist: String? = nil,
         artwork: MPMediaItemArtwork? = nil, albumArtist: String? = nil, albumTitle: String? = nil) {
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
    }

    init(mediaType: MPNowPlayingInfoMediaType? = nil, isLiveStream: Bool? = nil, title: String, artist: String? = nil, image: UIImage, albumArtist: String? = nil, albumTitle: String? = nil) {
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
        artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
