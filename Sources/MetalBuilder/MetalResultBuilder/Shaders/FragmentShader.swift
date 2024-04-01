
enum FragmentShaderError: Error{
    case noFragmentOut(String)//label
    case noBody(String)//label
    case noVertexOut(String)//label
}
extension FragmentShaderError: LocalizedError{
    public var errorDescription: String?{
        switch self {
        case .noFragmentOut(let label):
            "Fragment shader for \(label) has no return type declaration!"
        case .noBody(let label):
            "Fragment shader for \(label) has no body!"
        case .noVertexOut(let label):
            "Fragment shader for \(label) cannot be constructed from body since VertexOut is unknown!"
        }
    }
}

import SwiftUI

/// Fragment Shader that you pass to a Render component
///
/// All the uniforms that are passed to the Render component will be also available
/// in the Metal code of the shader function:
/// ```
/// Render()
///     .uniforms(uniforms)
///     .fragmentShader(fragment)
/// ```
/// You also may pass any uniforms, buffers or textures directly to the shaders using modifiers:
///```
/// Render()
///     .fragmentShader(
///         fragment
///             .texture(imageTexture)
///             .buffer(colorsBuffer)
///     )
/// ```
public struct FragmentShader: ShaderProtocol{
    
    public var argumentsContainer = ArgumentsContainer(stages: .fragment)
    public var gridFit: GridFit?
    
    /// Creates the FragmentShader
    public init(){
    }
    
    var fragmentOutFields: String?
    var fragmentOutType: String?
    
    public var _body: String?
    public var _source: String?
    
    func getFragmentOut(label: String) throws -> (String, String){//FragmentOut (Type, decl)
        if let fragmentOutType{
            return (fragmentOutType, "")
        }
        guard let fragmentOutFields
        else {
            return  ("float4", "")
//            throw FragmentShaderError
//                .noFragmentOut(label)
        }
        let fragmentOut = "\(label)FragmentOut"
        let decl = """
                   struct \(fragmentOut){
                     \(fragmentOutFields)
                   };
                   """
        return (fragmentOut, decl)
    }
    
    func librarySource(label: String, vertexOut: String?) throws -> String{
        if let source = _source{
            return source
        }
        guard let _body
        else {
            throw FragmentShaderError
                .noBody(label)
        }
        guard let vertexOut
        else {
            throw FragmentShaderError
                .noVertexOut(label)
        }
        let (type, decl) = try getFragmentOut(label: label)
        let fragmentName = fragmentNameFromLabel(label)
        
        return """
                \(decl) fragment \(type) \(fragmentName)(\(vertexOut) in [[stage_in]]){
                \(type) out;
                \(_body)
                return out;
                }
               """
    }
}
/*
//FragmentShader's wrappers for ShaderProtocol modifiers
public extension FragmentShader{
    func buffer<T>(_ container: MTLBufferContainer<T>, offset: MetalBinding<Int>, argument: MetalBufferArgument) -> FragmentShader{
        return _buffer(container, offset: offset, argument: argument) as! FragmentShader
    }
    func bytes<T>(_ binding: Binding<T>, argument: MetalBytesArgument) -> FragmentShader{
        return _bytes(binding, argument: argument) as! FragmentShader
    }
    func bytes<T>(_ binding: MetalBinding<T>, space: String = "constant", type: String?=nil, name: String?=nil, index: Int?=nil)->FragmentShader{
        return _bytes(binding, space: space, type: type, name: name, index: index) as! FragmentShader
    }
    func texture(_ container: MTLTextureContainer, argument: MetalTextureArgument) -> FragmentShader{
        return _texture(container, argument: argument) as! FragmentShader
    }
    func uniforms(_ uniforms: UniformsContainer, name: String?=nil) -> FragmentShader{
        return _uniforms(uniforms, name: name) as! FragmentShader
    }
    func source(_ source: String)->FragmentShader{
        return _source(source) as! FragmentShader
    }
    func body(_ body: String)->FragmentShader{
        return _body(body) as! FragmentShader
    }
}
*/
//Modifiers specific to FragmentShader
public extension FragmentShader{
    ///  Adds the declaration of fields of the C-struct that used as output of the fragment shader
    /// - Parameter fields: Declaration of fields of the output type.
    /// - Returns: Fragment shader with the added declaration of output type.
    ///
    ///Example:
    ///```
    ///FragmentShader()
    ///     .fragmentOut("""
    ///         float4 color;
    ///         float depth;
    ///     """)
    ///```
    func fragmentOut(_ fields: String)->FragmentShader{
        var v = self
        v.fragmentOutFields = fields
        return v
    }
    ///  Adds a Metal type as output of the fragment shader
    /// - Parameter metalType: Metal type name for shader output.
    /// - Returns: Fragment shader with the added output type.
    ///
    ///Example:
    ///```
    ///FragmentShader()
    ///     .returns("float")
    ///```
    func returns(_ metalType: String)->FragmentShader{
        var v = self
        v.fragmentOutType = metalType
        return v
    }
}
