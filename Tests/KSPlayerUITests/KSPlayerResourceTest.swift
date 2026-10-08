import Foundation
import KSPlayer
@testable import KSPlayerUI
import Testing

@MainActor
final class KSPlayerResourceTest {
    @Test
    func `single definition resource`() throws {
        let url = try #require(URL(string: "https://example.com/video.mp4"))
        let options = KSOptions()
        let resource = KSPlayerResource(url: url, options: options, name: "Test Video")

        // 测试基本属性
        #expect(resource.name == "Test Video")
        #expect(resource.definitions.count == 1)
        #expect(resource.definitions[0].url == url)
        #expect(resource.definitions[0].definition == "")
        #expect(resource.cover == nil)
        #expect(resource.subtitleDataSource == nil)
    }

    @Test
    func `multiple definition resource`() throws {
        let hdUrl = try #require(URL(string: "https://example.com/video_hd.mp4"))
        let sdUrl = try #require(URL(string: "https://example.com/video_sd.mp4"))
        let coverUrl = try #require(URL(string: "https://example.com/cover.jpg"))

        let options = KSOptions()
        let hdDefinition = KSPlayerResourceDefinition(url: hdUrl, definition: "高清", options: options)
        let sdDefinition = KSPlayerResourceDefinition(url: sdUrl, definition: "标清", options: options)

        let resource = KSPlayerResource(
            name: "Multi Definition Video",
            definitions: [hdDefinition, sdDefinition],
            cover: coverUrl
        )

        // 测试多清晰度配置
        #expect(resource.name == "Multi Definition Video")
        #expect(resource.definitions.count == 2)
        #expect(resource.definitions[0].definition == "高清")
        #expect(resource.definitions[1].definition == "标清")
        #expect(resource.cover == coverUrl)
    }

    @Test
    func `resource with subtitle`() throws {
        let url = try #require(URL(string: "https://example.com/video.mp4"))
        let subtitleUrl = try #require(URL(string: "https://example.com/subtitle.srt"))

        let options = KSOptions()
        let resource = KSPlayerResource(
            url: url,
            options: options,
            name: "Video with Subtitle",
            cover: nil,
            subtitleURLs: [subtitleUrl]
        )

        // 测试字幕配置
        #expect(resource.subtitleDataSource != nil)
        #expect(resource.name == "Video with Subtitle")
    }

    @Test
    func `resource definition with options`() throws {
        let url = try #require(URL(string: "https://example.com/video.mp4"))
        let options = KSOptions()
        options.startPlayRate = 1.5
        options.isLoopPlay = true

        let definition = KSPlayerResourceDefinition(
            url: url,
            definition: "自定义",
            options: options
        )

        // 测试定义配置
        #expect(definition.url == url)
        #expect(definition.definition == "自定义")
        #expect(definition.options.startPlayRate == 1.5)
        #expect(definition.options.isLoopPlay == true)
    }

    @Test
    func `resource copy`() throws {
        let url = try #require(URL(string: "https://example.com/video.mp4"))
        let coverUrl = try #require(URL(string: "https://example.com/cover.jpg"))
        let subtitleUrl = try #require(URL(string: "https://example.com/subtitle.srt"))

        let options = KSOptions()
        let originalResource = KSPlayerResource(
            url: url,
            options: options,
            name: "Original Video",
            cover: coverUrl,
            subtitleURLs: [subtitleUrl]
        )

        // 复制资源并修改名称
        let copiedResource = KSPlayerResource(
            name: "Copied Video",
            definitions: originalResource.definitions,
            cover: originalResource.cover,
            subtitleDataSource: originalResource.subtitleDataSource
        )

        // 验证复制结果
        #expect(copiedResource.name == "Copied Video")
        #expect(copiedResource.definitions.count == originalResource.definitions.count)
        #expect(copiedResource.cover == originalResource.cover)
        #expect(copiedResource.subtitleDataSource === originalResource.subtitleDataSource)
    }

    @Test
    func `empty resource`() {
        let resource = KSPlayerResource(name: "Empty", definitions: [], cover: nil)

        // 测试空资源
        #expect(resource.name == "Empty")
        #expect(resource.definitions.isEmpty)
        #expect(resource.cover == nil)
        #expect(resource.subtitleDataSource == nil)
    }

    @Test
    func `resource equality`() throws {
        let url1 = try #require(URL(string: "https://example.com/video1.mp4"))
        let url2 = try #require(URL(string: "https://example.com/video2.mp4"))

        let options = KSOptions()
        let resource1 = KSPlayerResource(url: url1, options: options, name: "Video 1")
        let resource2 = KSPlayerResource(url: url1, options: options, name: "Video 1")
        let resource3 = KSPlayerResource(url: url2, options: options, name: "Video 2")

        // 测试资源相等性（基于URL和名称）
        #expect(resource1.name == resource2.name)
        #expect(resource1.definitions[0].url == resource2.definitions[0].url)
        #expect(resource1.name != resource3.name)
        #expect(resource1.definitions[0].url != resource3.definitions[0].url)
    }

    @Test
    func `local resource`() {
        let bundle = Bundle(for: Self.self)
        guard let path = bundle.path(forResource: "h264", ofType: "mp4") else { return }
        let url = URL(fileURLWithPath: path)
        let resource = KSPlayerResource(url: url, options: KSOptions())

        #expect(resource.definitions.first?.url.isFileURL == true)
    }
}
