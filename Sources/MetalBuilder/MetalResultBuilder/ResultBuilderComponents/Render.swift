import MetalKit
import SwiftUI

enum MetalDSPRenderSetupError: Error{
    //case noGridFit(String)
}
/// color attachment with bindings
struct ColorAttachment{
    var texture: MTLTextureContainer?
    var loadAction: Binding<MTLLoadAction>?
    var storeAction: Binding<MTLStoreAction>?
    var clearColor: Binding<MTLClearColor>?
    
    var descriptor: MTLRenderPassColorAttachmentDescriptor{
        let d = MTLRenderPassColorAttachmentDescriptor()
        d.texture = texture?.texture
        if let loadAction = loadAction?.wrappedValue{
            d.loadAction = loadAction
        }
        if let storeAction = storeAction?.wrappedValue{
            d.storeAction = storeAction
        }
        if let clearColor = clearColor?.wrappedValue{
            d.clearColor = clearColor
        }
        return d
    }
}
/// default color attachments
var defaultColorAttachments =
    [0:ColorAttachment(texture: nil,
                       loadAction: Binding<MTLLoadAction>(
                        get: { .clear },
                        set: { _ in }),
                       storeAction: Binding<MTLStoreAction>(
                        get: { .store },
                        set: { _ in }),
                       clearColor: Binding<MTLClearColor>(
                        get: { MTLClearColorMake(0.0, 0.0, 0.0, 1.0)},
                        set: { _ in } )
                       )]

public struct FragmentShader{
    public init(_ name: String, source: String=""){
        self.fragmentFunc = name
        self.librarySource = source
    }
    
    let fragmentFunc: String
    
    var librarySource: String
    
    var bufsAndArgs: [(BufferProtocol, MetalBufferArgument)] = []
    var bytesAndArgs: [(BytesProtocol, MetalBytesArgument)] = []
    var texsAndArgs: [(Texture, MetalTextureArgument)] = []
    
    var uniformsAndNames: [(UniformsContainer, String?)] = []
}

public extension FragmentShader{
    func buffer<T>(_ container: MTLBufferContainer<T>, offset: Int, argument: MetalBufferArgument) -> FragmentShader{
        var f = self
        let buf = Buffer(container: container, offset: offset, index: 0)
        f.bufsAndArgs.append((buf, argument))
        return f
    }
    func bytes<T>(_ binding: Binding<T>, argument: MetalBytesArgument) -> FragmentShader{
        var f = self
        let bytes = Bytes(binding: binding, index: 0)
        f.bytesAndArgs.append((bytes, argument))
        return f
    }
    func texture(_ container: MTLTextureContainer, argument: MetalTextureArgument) -> FragmentShader{
        var f = self
        let tex = Texture(container: container, index: 0)
        f.texsAndArgs.append((tex, argument))
        return f
    }
    func uniforms(_ uniforms: UniformsContainer, name: String?=nil) -> FragmentShader{
        var f = self
        f.uniformsAndNames.append((uniforms, name))
        return f
    }
    func source(_ source: String)->FragmentShader{
        var f = self
        f.librarySource = source
        return f
    }
}

/// Render Component
public struct Render: MetalBuilderComponent{
    
    let vertexFunc: String
    var fragmentFunc: String
    
    var librarySource: String
    
    var type: MTLPrimitiveType!
    var vertexOffset: Int = 0
    var vertexCount: Int = 0
    
    var indexCount: MetalBinding<Int> = MetalBinding<Int>.constant(0)
    var indexBufferOffset: Int = 0
    var indexedPrimitives = false
    
    var viewport: Binding<MTLViewport>?
    
    var indexBuf: BufferProtocol?
    
    var vertexBufs: [BufferProtocol] = []
    var vertexBytes: [BytesProtocol] = []
    var vertexTextures: [Texture] = []
    
    var fragBufs: [BufferProtocol] = []
    var fragBytes: [BytesProtocol] = []
    var fragTextures: [Texture] = []
    
    var colorAttachments: [Int: ColorAttachment] = defaultColorAttachments
    
    var vertexArguments: [MetalFunctionArgument] = []
    var fragmentArguments: [MetalFunctionArgument] = []
    
    var vertexBufferIndexCounter = 0
    var fragmentBufferIndexCounter = 0
    var vertexTextureIndexCounter = 0
    var fragmentTextureIndexCounter = 0
    
    var depthDescriptor: MTLDepthStencilDescriptor?
    
    var uniforms: [UniformsContainer] = []
    
    public init(vertex: String, fragment: String="", type: MTLPrimitiveType = .triangle,
                offset: Int = 0, count: Int = 3, source: String=""){
        self.vertexFunc = vertex
        self.fragmentFunc = fragment
        
        self.librarySource = source
        
        self.type = type
        self.vertexOffset = offset
        self.vertexCount = count
    }
    
    public init<T>(vertex: String, fragment: String="", type: MTLPrimitiveType = .triangle,
                indexBuffer: MTLBufferContainer<T>,
                   indexOffset: Int = 0, indexCount: MetalBinding<Int>, source: String=""){
        self.indexBuf = Buffer(container: indexBuffer, offset: 0, index: 0)
        
        self.vertexFunc = vertex
        self.fragmentFunc = fragment
        
        self.librarySource = source
        
        self.type = type
        
        self.indexCount = indexCount
        self.indexBufferOffset = indexOffset
        self.indexedPrimitives = true
    }
    
    mutating func setup() throws{
    }
}

//private non-generic chain modifiers
extension Render{
    func vertexBuf(_ buf: BufferProtocol, argument: MetalBufferArgument)->Render{
        var r = self
        var argument = argument
        argument.index = checkVertexBufferIndex(r: &r, index: argument.index)
        r.vertexArguments.append(MetalFunctionArgument.buffer(argument))
        var buf = buf
        buf.index = argument.index!
        r.vertexBufs.append(buf)
        return r
    }
    func vertexBytes(_ bytes: BytesProtocol, argument: MetalBytesArgument)->Render{
        var r = self
        var argument = argument
        argument.index = checkVertexBufferIndex(r: &r, index: argument.index)
        r.vertexArguments.append(.bytes(argument))
        var bytes = bytes
        bytes.index = argument.index!
        r.vertexBytes.append(bytes)
        return r
    }
    func vertexTexture(_ tex: Texture, argument: MetalTextureArgument)->Render{
        var r = self
        var argument = argument
        argument.index = checkVertexTextureIndex(r: &r, index: argument.index)
        argument.textureType = tex.container.descriptor.type
        r.vertexArguments.append(.texture(argument))
        var tex = tex
        tex.index = argument.index!
        r.vertexTextures.append(tex)
        return r
    }
    func fragBuf(_ buf: BufferProtocol, argument: MetalBufferArgument)->Render{
        var r = self
        var argument = argument
        argument.index = checkFragmentBufferIndex(r: &r, index: argument.index)
        r.fragmentArguments.append(.buffer(argument))
        var buf = buf
        buf.index = argument.index!
        r.fragBufs.append(buf)
        return r
    }
    func fragBytes(_ bytes: BytesProtocol, argument: MetalBytesArgument)->Render{
        var r = self
        var argument = argument
        argument.index = checkFragmentBufferIndex(r: &r, index: argument.index)
        r.fragmentArguments.append(.bytes(argument))
        var bytes = bytes
        bytes.index = argument.index!
        r.fragBytes.append(bytes)
        return r
    }
    func fragTexture(_ tex: Texture, argument: MetalTextureArgument)->Render{
        var r = self
        var argument = argument
        argument.index = checkVertexTextureIndex(r: &r, index: argument.index)
        argument.textureType = tex.container.descriptor.type
        r.fragmentArguments.append(.texture(argument))
        var tex = tex
        tex.index = argument.index!
        r.fragTextures.append(tex)
        return r
    }
}
// chaining functions for result builder
public extension Render{
    func vertexBuf<T>(_ container: MTLBufferContainer<T>, offset: Int = 0, index: Int)->Render{
        var r = self
        let buf = Buffer(container: container, offset: offset, index: index)
        r.vertexBufs.append(buf)
        return r
    }
    func vertexBuf<T>(_ container: MTLBufferContainer<T>, offset: Int = 0, argument: MetalBufferArgument)->Render{
        let buf = Buffer(container: container, offset: offset, index: 0)
        return self.vertexBuf(buf, argument: argument)
    }
    func vertexBuf<T>(_ container: MTLBufferContainer<T>, offset: Int = 0,
                   space: String = "constant", type: String?=nil, name: String?=nil) -> Render{
        
        let argument = try! MetalBufferArgument(container, space: space, type: type, name: name)

        return self.vertexBuf(container, offset: offset, argument: argument)
    }
    func fragBuf<T>(_ container: MTLBufferContainer<T>, offset: Int, index: Int)->Render{
        var r = self
        let buf = Buffer(container: container, offset: offset, index: index)
        r.fragBufs.append(buf)
        return r
    }
    func fragBuf<T>(_ container: MTLBufferContainer<T>, offset: Int, argument: MetalBufferArgument)->Render{
        let buf = Buffer(container: container, offset: offset, index: 0)
        return self.fragBuf(buf, argument: argument)
    }
    func fragBuf<T>(_ container: MTLBufferContainer<T>, offset: Int = 0,
                   space: String="constant", type: String?=nil, name: String?=nil) -> Render{
        
        let argument = try! MetalBufferArgument(container, space: space, type: type, name: name)

        return self.fragBuf(container, offset: offset, argument: argument)
        
    }
    func vertexBytes<T>(_ binding: Binding<T>, index: Int)->Render{
        var r = self
        let bytes = Bytes(binding: binding, index: index)
        r.vertexBytes.append(bytes)
        return r
    }
    func vertexBytes<T>(_ binding: Binding<T>, argument: MetalBytesArgument)->Render{
        let bytes = Bytes(binding: binding, index: 0)
        return self.vertexBytes(bytes, argument: argument)
    }
    func vertexBytes<T>(_ binding: MetalBinding<T>, argument: MetalBytesArgument)->Render{
        self.vertexBytes(binding.binding, argument: argument)
    }
    func vertexBytes<T>(_ binding: MetalBinding<T>, space: String = "constant", type: String?=nil, name: String?=nil, index: Int?=nil)->Render{
        let argument = MetalBytesArgument(binding: binding, space: space, type: type, name: name)
        return vertexBytes(binding, argument: argument)
    }
    func vertexBytes<T>(_ binding: Binding<T>, space: String = "constant", type: String?=nil, name: String, index: Int?=nil)->Render{
        let metalBinding = MetalBinding(binding: binding, metalType: type, metalName: name)
        let argument = MetalBytesArgument(binding: metalBinding, space: space, type: type, name: name)
        return vertexBytes(binding, argument: argument)
    }
    func fragBytes<T>(_ binding: Binding<T>, index: Int)->Render{
        var r = self
        let bytes = Bytes(binding: binding, index: index)
        r.fragBytes.append(bytes)
        return r
    }
    func fragBytes<T>(_ binding: MetalBinding<T>, argument: MetalBytesArgument)->Render{
        let bytes = Bytes(binding: binding.binding, index: 0)
        return self.fragBytes(bytes, argument: argument)
    }
    func fragBytes<T>(_ binding: Binding<T>, argument: MetalBytesArgument)->Render{
        var r = self
        var argument = argument
        argument.index = checkFragmentBufferIndex(r: &r, index: argument.index)
        r.fragmentArguments.append(.bytes(argument))
        let bytes = Bytes(binding: binding, index: argument.index!)
        r.fragBytes.append(bytes)
        return r
    }
    func fragBytes<T>(_ binding: MetalBinding<T>, space: String = "constant", type: String?=nil, name: String?=nil, index: Int?=nil)->Render{
        let argument = MetalBytesArgument(binding: binding, space: space, type: type, name: name)
        return fragBytes(binding, argument: argument)
    }
    func fragBytes<T>(_ binding: Binding<T>, space: String = "constant", type: String?=nil, name: String, index: Int?=nil)->Render{
        let metalBinding = MetalBinding(binding: binding, metalType: type, metalName: name)
        let argument = MetalBytesArgument(binding: metalBinding, space: space, type: type, name: name)
        return fragBytes(binding, argument: argument)
    }
    func uniforms(_ uniforms: UniformsContainer, name: String?=nil) -> Render{
        var r = self
        r.uniforms.append(uniforms)
        var argument = MetalBytesArgument(uniformsContainer: uniforms, name: name)
        //Add to vertex shader
        argument.index = checkVertexBufferIndex(r: &r, index: nil)
        r.vertexArguments.append(.bytes(argument))
        let vertexBytes = RawBytes(binding: uniforms.pointerBinding,
                             length: uniforms.length,
                             index: argument.index!)
        r.vertexBytes.append(vertexBytes)
        //add to fragment shader
        argument.index = checkFragmentBufferIndex(r: &r, index: nil)
        r.fragmentArguments.append(.bytes(argument))
        let fragBytes = RawBytes(binding: uniforms.pointerBinding,
                             length: uniforms.length,
                             index: argument.index!)
        r.fragBytes.append(fragBytes)
        
        return r
    }
    func vertexTexture(_ container: MTLTextureContainer, index: Int)->Render{
        var r = self
        let tex = Texture(container: container, index: index)
        r.vertexTextures.append(tex)
        return r
    }
    func vertexTexture(_ container: MTLTextureContainer, argument: MetalTextureArgument)->Render{
        let tex = Texture(container: container, index: 0)
        return self.vertexTexture(tex, argument: argument)
    }
    func fragTexture(_ container: MTLTextureContainer, index: Int)->Render{
        var r = self
        let tex = Texture(container: container, index: index)
        r.fragTextures.append(tex)
        return r
    }
    func fragTexture(_ container: MTLTextureContainer, argument: MetalTextureArgument)->Render{
        let tex = Texture(container: container, index: 0)
        return self.fragTexture(tex, argument: argument)
    }
    func viewport(_ viewport: Binding<MTLViewport>)->Render{
        var r = self
        r.viewport = viewport
        return r
    }
    /// Adds destination texture for the render pass. if `nill` is passed and there no other modifier with no-nil container,
    /// the drawable texture will be set as output.
    /// - Parameters:
    ///   - container: the destination texture
    ///   - index: index of the texture if you write metal declarations manually
    /// - Returns: <#description#>
    func toTexture(_ container: MTLTextureContainer?, index: Int = 0)->Render{
        var r = self
        if let container = container {
            var a: ColorAttachment
            if let aExistent = colorAttachments[index]{
                a = aExistent
            }else{
                a = ColorAttachment()
            }
            a.texture = container
            r.colorAttachments[index] = a
        }
        return r
    }
    func source(_ source: String)->Render{
        var r = self
        r.librarySource = source + r.librarySource
        return r
    }
    func fragmentShader(_ shader: FragmentShader)->Render{
        var r = self
        //func
        r.fragmentFunc = shader.fragmentFunc
        //source
        r.librarySource += shader.librarySource
        //add buffer
        for bufAndArg in shader.bufsAndArgs{
            r = r.fragBuf(bufAndArg.0, argument: bufAndArg.1)
        }
        //add bytes
        for byteAndArg in shader.bytesAndArgs{
            r = r.fragBytes(byteAndArg.0, argument: byteAndArg.1)
        }
        //add textures
        for texAndArg in shader.texsAndArgs{
            r = r.fragTexture(texAndArg.0, argument: texAndArg.1)
        }
        //uniforms
        for uAndName in shader.uniformsAndNames{
            r = r.uniforms(uAndName.0, name: uAndName.1)
        }
        return r
    }
    func depthDescriptor(_ descriptor: MTLDepthStencilDescriptor) -> Render{
        var r = self
        r.depthDescriptor = descriptor
        return r
    }
}

extension Render{
    func checkVertexBufferIndex(r: inout Render, index: Int?) -> Int{
        if index == nil {
            let index = vertexBufferIndexCounter
            r.vertexBufferIndexCounter += 1
            return index
        }else{
            return index!
        }
    }
    func checkVertexTextureIndex(r: inout Render, index: Int?) -> Int{
        if index == nil {
            let index = vertexTextureIndexCounter
            r.vertexTextureIndexCounter += 1
            return index
        }else{
            return index!
        }
    }
    func checkFragmentBufferIndex(r: inout Render, index: Int?) -> Int{
        if index == nil {
            let index = fragmentBufferIndexCounter
            r.fragmentBufferIndexCounter += 1
            return index
        }else{
            return index!
        }
    }
    func checkFragmentTextureIndex(r: inout Render, index: Int?) -> Int{
        if index == nil {
            let index = fragmentTextureIndexCounter
            r.fragmentTextureIndexCounter += 1
            return index
        }else{
            return index!
        }
    }
}
