import GLKit
#if !os(OSX)
final class OpenGLTexture {
    private var videoTextureCache: CVOpenGLESTextureCache?
    private var glContext: EAGLContext

    init(context: EAGLContext) {
        glContext = context
        let result: CVReturn = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, glContext, nil, &videoTextureCache)
        if result != noErr {
            KSLog("create OpenGLESTextureCacheCreate failure")
        }
    }

    func refreshTextureWithPixelBuffer(pixelBuffer: CVPixelBuffer) {
        guard let videoTextureCache = videoTextureCache else {
            KSLog("no video texture cache")
            return
        }
        cleanTextures()
        let textureWidth: GLsizei = GLsizei(pixelBuffer.width)
        let textureHeight: GLsizei = GLsizei(pixelBuffer.height)
        var lumaTexture: CVOpenGLESTexture?
        var chromaTexture: CVOpenGLESTexture?
        glActiveTexture(GLenum(GL_TEXTURE0))
        var result: CVReturn
        result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                              videoTextureCache,
                                                              pixelBuffer,
                                                              nil,
                                                              GLenum(GL_TEXTURE_2D),
                                                              GL_RED_EXT,
                                                              textureWidth,
                                                              textureHeight,
                                                              GLenum(GL_RED_EXT),
                                                              GLenum(GL_UNSIGNED_BYTE),
                                                              0,
                                                              &lumaTexture)
        if result != 0 {
            KSLog("create CVOpenGLESTextureCacheCreateTextureFromImage failure 1 \(result)")
        }
        glBindTexture(CVOpenGLESTextureGetTarget(lumaTexture!), CVOpenGLESTextureGetName(lumaTexture!))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))

        // UV-plane.
        glActiveTexture(GLenum(GL_TEXTURE1))
        result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                              videoTextureCache,
                                                              pixelBuffer,
                                                              nil,
                                                              GLenum(GL_TEXTURE_2D),
                                                              GL_RG_EXT,
                                                              textureWidth / 2,
                                                              textureHeight / 2,
                                                              GLenum(GL_RG_EXT),
                                                              GLenum(GL_UNSIGNED_BYTE),
                                                              1,
                                                              &chromaTexture)
        if result != 0 {
            KSLog("create CVOpenGLESTextureCacheCreateTextureFromImage failure 2 \(result)")
        }
        glBindTexture(CVOpenGLESTextureGetTarget(chromaTexture!), CVOpenGLESTextureGetName(chromaTexture!))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
    }

    deinit {
        cleanTextures()
        videoTextureCache = nil
    }

    private func cleanTextures() {
        CVOpenGLESTextureCacheFlush(videoTextureCache!, 0)
    }
}
#endif
