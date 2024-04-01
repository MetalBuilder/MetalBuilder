import SwiftUI

public protocol ShaderProtocol: ReceiverOfArgumentsContainer {
    var _body: String? { get set}
    var _source: String? { get set }
}
public extension ShaderProtocol{
    func source(_ source: String)->Self{
        var sh = self
        sh._source = source
        return sh
    }
    func body(_ body: String)->Self{
        var sh = self
        sh._body = body
        return sh
    }
}

//Internal implementation for ShaderProtocol's logic
//This is hidden from the client
protocol InternalShaderProtocol: ShaderProtocol{
    var bufsAndArgs: [(BufferProtocol, MetalBufferArgument)] { get set }
    var bytesAndArgs: [(BytesProtocol, MetalBytesArgument)] { get set }
    var texsAndArgs: [(Texture, MetalTextureArgument)] { get set }
    
    var uniformsAndNames: [(UniformsContainer, String?)] { get set }
}

//Implementation of public modifiers for ShaderProtocol
//They are to be called by wrappers of the respective shaders
extension InternalShaderProtocol{
    func _buffer<T>(_ container: MTLBufferContainer<T>,
                    offset: MetalBinding<Int> = .constant(0), argument: MetalBufferArgument) -> ShaderProtocol{
        var sh = self
        let buf = Buffer(container: container, offset: offset, index: 0)
        sh.bufsAndArgs.append((buf, argument))
        return sh
    }
    func _bytes<T>(_ binding: Binding<T>, argument: MetalBytesArgument) -> ShaderProtocol{
        var sh = self
        let bytes = Bytes(binding: binding, index: 0)
        sh.bytesAndArgs.append((bytes, argument))
        return sh
    }
    func _bytes<T>(_ binding: MetalBinding<T>, space: String = "constant", type: String?=nil, name: String?=nil, index: Int?=nil)->ShaderProtocol{
        let argument = MetalBytesArgument(binding: binding, space: space, type: type, name: name)
        return _bytes(binding.binding, argument: argument)
    }
    func _texture(_ container: MTLTextureContainer, argument: MetalTextureArgument) -> ShaderProtocol{
        var sh = self
        let tex = Texture(container: container, index: 0)
        sh.texsAndArgs.append((tex, argument))
        return sh
    }
    func _uniforms(_ uniforms: UniformsContainer, name: String?=nil) -> ShaderProtocol{
        var sh = self
        sh.uniformsAndNames.append((uniforms, name))
        return sh
    }
    
}

func getTypeFromFromStructDeclaration(_ source: String) ->String?{
    let structRange = source.range(of: "struct ")
    guard let startIndex = structRange?.upperBound
    else{ return nil }
    guard let endIndex = source[startIndex...].firstIndex(of: "{")
    else { return nil }

    return ""+source[startIndex...source.index(before: endIndex)]
}

