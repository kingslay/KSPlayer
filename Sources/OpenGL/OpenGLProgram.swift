#if !targetEnvironment(macCatalyst) && !os(macOS)

import GLKit

final class OpenGLProgram {
    private var attributes: NSMutableArray = []
    private var uniforms: NSMutableArray = []
    private var program = glCreateProgram()
    private var vertexShader: GLuint = 0
    private var fragmentShader: GLuint = 0

    init() {
        if !compileShader(&vertexShader, type: GLenum(GL_VERTEX_SHADER), file: Bundle(for: type(of: self)).path(forResource: "Shader", ofType: "vsh")!) {
            KSLog("shader failure")
        }
        if !compileShader(&fragmentShader, type: GLenum(GL_FRAGMENT_SHADER), file: Bundle(for: type(of: self)).path(forResource: "Shader", ofType: "fsh")!) {
            KSLog("shader failure")
        }
        glAttachShader(program, vertexShader)
        glAttachShader(program, fragmentShader)
    }

    func addAttribute(attributeName: String) {
        if attributes.contains(attributeName) { return }
        attributes.add(attributeName)
        glBindAttribLocation(program, GLuint(attributes.index(of: attributeName)), NSString(string: attributeName).utf8String)
    }

    func attributeIndex(attributeName: String) -> GLuint {
        return GLuint(attributes.index(of: attributeName))
    }

    func uniformIndex(uniformName: String) -> GLuint {
        return GLuint(glGetUniformLocation(program, NSString(string: uniformName).utf8String))
    }

    func link() -> Bool {
        var status: GLint = 0
        glLinkProgram(program)

        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)

        if status == GL_FALSE {
            return false
        }
        if vertexShader > 0 {
            glDeleteShader(vertexShader)
            vertexShader = 0
        }
        if fragmentShader > 0 {
            glDeleteShader(fragmentShader)
            fragmentShader = 0
        }

        return true
    }

    func use() {
        glUseProgram(program)
    }

    private func compileShader(_ shader: inout GLuint, type: GLenum, file: String) -> Bool {
        var status: GLint = 0
        var source: UnsafePointer<Int8>
        do {
            source = try NSString(contentsOfFile: file, encoding: String.Encoding.utf8.rawValue).utf8String!
        } catch {
            KSLog("Failed to load vertex shader")
            return false
        }
        var castSource: UnsafePointer<GLchar>? = UnsafePointer<GLchar>(source)
        shader = glCreateShader(type)
        glShaderSource(shader, 1, &castSource, nil)
        glCompileShader(shader)

        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        if status == 0 {
            glDeleteShader(shader)
            return false
        }
        return true
    }
}
#endif
