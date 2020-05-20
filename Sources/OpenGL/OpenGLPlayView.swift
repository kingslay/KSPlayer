import CoreMedia
extension UIView {
    func updateViewport(size: CGSize) -> CGSize {
        let contentsGravity = backingLayer?.contentsGravity ?? CALayerContentsGravity.resizeAspect
        return bounds.size.resize(naturalSize: size, contentsGravity: contentsGravity)
    }
}

extension CGSize {
    func resize(naturalSize: CGSize, contentsGravity: CALayerContentsGravity) -> CGSize {
        if contentsGravity == .resize {
            return self
        } else {
            var newWidth = width
            var newHeight = ceil(naturalSize.height * width / naturalSize.width)
            if newHeight > height {
                newHeight = height
                if contentsGravity == .resizeAspect {
                    newWidth = ceil(naturalSize.width * height / naturalSize.height)
                }
            }
            return CGSize(width: newWidth, height: newHeight)
        }
    }
}

#if !targetEnvironment(macCatalyst) && !os(macOS)

import GLKit
#if os(macOS)
public typealias GLKView = NSOpenGLView
public typealias EAGLContext = NSOpenGLContext
#endif
class OpenGLPlayView: GLKView, PixelRenderView {
    private var drawableSize = CGSize(width: 1, height: 1) {
        didSet {
            if drawableSize != oldValue {
                updateViewport()
            }
        }
    }

    private var viewport = CGRect.zero
    private var vertexTexCoordAttributeIndex: GLuint = 0
    private var uniformY: GLuint = 0
    private var uniformUV: GLuint = 0
    private var uniformColorConversionMartrix: GLuint = 0
    private lazy var program = OpenGLProgram()
    private var defaultMatrix: [Float] = [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    ]
    var uniformModelViewProjectionMatrix: GLuint = 0
    var texture: OpenGLTexture?
    var vertices: [Float] = [
        -1.0, -1.0, 0.0,
        1.0, -1.0, 0.0,
        -1.0, 1.0, 0.0,
        1.0, 1.0, 0.0,
    ]
    var textCoord: [Float] = [
        0.0, 1.0,
        1.0, 1.0,
        0.0, 0.0,
        1.0, 0.0,
    ]

    public convenience init() {
        self.init(frame: UIScreen.main.bounds)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureGLKView()
        configureTexture()
        configureProgram()
        configureBuffer()
        configureUniform()
    }

    deinit {
        glFinish()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func matrixWithSize(size _: CGSize) -> [Float] {
        defaultMatrix
    }

    private func configureGLKView() {
        drawableDepthFormat = GLKViewDrawableDepthFormat.format24
        context = EAGLContext(api: .openGLES2)!
        EAGLContext.setCurrent(context)
        glClearColor(0, 0, 0, 1)
        glEnable(GLenum(GL_CULL_FACE)) // 开启面剔除
        glCullFace(GLenum(GL_BACK)) // 剔除背面
        glDisable(GLenum(GL_DEPTH_TEST))
//        var depthRenderBuffer = GLuint()
//        glGenRenderbuffers(1, &depthRenderBuffer)
//        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), depthRenderBuffer)
//        glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16), GLsizei(frame.size.width), GLsizei(frame.size.height))
//        var colorRenderBuffer = GLuint()
//        var framebuffer: GLuint = 0
//        glGenRenderbuffers(1, &colorRenderBuffer)
//        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorRenderBuffer)
//        context.renderbufferStorage(Int(GL_RENDERBUFFER), from: layer as? EAGLDrawable)
//        glGenFramebuffers(1, &framebuffer)
//        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
//        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0),
//                                  GLenum(GL_RENDERBUFFER), colorRenderBuffer)
//        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), depthRenderBuffer)
    }

    private func configureProgram() {
        program.addAttribute(attributeName: "position")
        program.addAttribute(attributeName: "texCoord")
        if !program.link() {
            KSLog("program failure")
        }
        vertexTexCoordAttributeIndex = program.attributeIndex(attributeName: "texCoord")
        uniformModelViewProjectionMatrix = program.uniformIndex(uniformName: "modelViewProjectionMatrix")
        uniformY = program.uniformIndex(uniformName: "SamplerY")
        uniformUV = program.uniformIndex(uniformName: "SamplerUV")
        uniformColorConversionMartrix = program.uniformIndex(uniformName: "colorConversionMatrix")
        program.use()
    }

    private func configureTexture() {
        texture = OpenGLTexture(context: context)
    }

    func configureBuffer() {
        // Vertex
        glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<Float>.size * 3), vertices)
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))

        // Texture Coordinates
        glVertexAttribPointer(vertexTexCoordAttributeIndex, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<Float>.size * 2), textCoord)
        glEnableVertexAttribArray(vertexTexCoordAttributeIndex)
    }

    private func configureUniform() {
        var array: [GLfloat] = [1.164, 1.164, 1.164, 0.0, -0.213, 2.112, 1.793, -0.533, 0.0]
        glUniform1i(GLint(uniformY), 0)
        glUniform1i(GLint(uniformUV), 1)
        glUniformMatrix3fv(GLint(uniformColorConversionMartrix), 1, GLboolean(GL_FALSE), &array)
        glUniformMatrix4fv(GLint(uniformModelViewProjectionMatrix), 1, GLboolean(GL_FALSE), matrixWithSize(size: bounds.size))
    }

    #if !os(macOS)
    override open func layoutSubviews() {
        super.layoutSubviews()
        updateViewport()
    }
    #endif
    func set(pixelBuffer: CVPixelBuffer, time _: CMTime) {
        autoreleasepool {
            drawableSize = pixelBuffer.drawableSize
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            glViewport(GLint(viewport.minX), GLint(viewport.minY), GLsizei(viewport.width), GLsizei(viewport.height))
            texture?.refreshTextureWithPixelBuffer(pixelBuffer: pixelBuffer)
            glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
            //            context.presentRenderbuffer(Int(GL_RENDERBUFFER))
        }
        #if os(macOS)
        setNeedsDisplay = true
        #else
        setNeedsDisplay()
        #endif
    }

    private func updateViewport() {
        let newSize = updateViewport(size: drawableSize)
        viewport = CGRect(origin: ((bounds.size - newSize) * 0.5).toPoint, size: newSize) * layer.contentsScale
    }
}
#endif
