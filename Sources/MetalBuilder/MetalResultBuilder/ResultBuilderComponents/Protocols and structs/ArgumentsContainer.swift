
import MetalKit
import SwiftUI

protocol ContainerOfResources{
    var indexCounter: Int{ get set }
}
extension ContainerOfResources{
    mutating func checkIndex(index: Int?) -> Int{
        if index == nil {
            let index = indexCounter
            indexCounter += 1
            return index
        }else{
            return index!
        }
    }
}

enum ResourceType{
    case texture
    case bytes
    case buffer
    case arrayOfTextures
}

struct ContainerOfBuffersBytesAndUniforms: ContainerOfResources{
    var indexCounter: Int = 0
    var buffers: [BufferProtocol] = []
    var bytes: [BytesProtocol] = []
    
    mutating func addBuffer(_ buf: BufferProtocol,
                               argument: MetalBufferArgument) -> MetalFunctionArgument{
        var argument = argument
        var buf = buf
        argument.index = checkIndex(index: argument.index)
        buf.index = argument.index!
        self.buffers.append(buf)
        return .buffer(argument)
    }
    mutating func addBytes(_ bytes: BytesProtocol,
                           argument: MetalBytesArgument)->MetalFunctionArgument{
        var argument = argument
        var bytes = bytes
        argument.index = checkIndex(index: argument.index)
        bytes.index = argument.index!
        self.bytes.append(bytes)
        return .bytes(argument)
    }
}

struct ContainerOfTextures: ContainerOfResources{
    var indexCounter: Int = 0
    var textures: [Texture] = []
    
    mutating func add(_ tex: Texture?,//if drawable the tex is nil
                      argument: MetalTextureArgument) -> MetalFunctionArgument{
        var argument = argument
        argument.index = checkIndex(index: argument.index)
        if var tex{
            tex.index = argument.index!
            self.textures.append(tex)
        }
        return .texture(argument)
    }
}

public struct ArgumentsContainer{
    
    var resourcesUsages = ResourcesUsages()
    var stages: MTLRenderStages?
    
    var separateShaderArguments: [MetalFunctionArgument] = []
    var addedArgumentBuffers: [(ArgumentBuffer, Int)] = [] //buffer, index of buffer in shader function args
    
    var uniforms: [UniformsContainer] = []
    var buffersAndBytesContainer = ContainerOfBuffersBytesAndUniforms()
    var texturesContainer = ContainerOfTextures()
    init(stages: MTLRenderStages?){
        self.stages = stages
    }
    func prerun(){//set buffer for arguments encoder once it created
        for argBuf in addedArgumentBuffers{
            argBuf.0.setEncoder()
        }
    }
}

//setup and other functions
extension ArgumentsContainer{
    
    func getData(metalFunction: MetalFunction) throws -> ArgumentsData{
        
        var argData = ArgumentsData(
            buffers: buffersAndBytesContainer.buffers,
            textures: texturesContainer.textures.map{ $0.container },
            uniforms: uniforms,
            funcAndArgs: separateShaderArguments.isEmpty ? [] :
                [FunctionAndArguments(function: metalFunction,
                                      arguments: separateShaderArguments)],
            argBufDecls: ""
        )
        
        for argBuf in addedArgumentBuffers{
            let argData1 = try argBuf.0.setup()
            argData.appendContents(of: argData1)
        }
        
        return argData
    }
    
    func createArgumentBuffers(device: MTLDevice, mtlFunction: MTLFunction) throws{
        for argBuf in addedArgumentBuffers{
            try argBuf.0.create(device: device,
                                mtlFunction: mtlFunction,
                                index: argBuf.1)
        }
    }
}

//chaning modifiers call these functions
extension ArgumentsContainer{
    mutating func argumentBufferToKernel(_ argBuf: ArgumentBuffer,
                                         name: String?,
                                         space: String,
                                         _ resources: UseResources)->GridFit?{
        checkIfArgumentBufferIsNew(argBuf)
        let buf = Buffer(container: argBuf.buffer, offset: .constant(0), index: 0)
        let argument = argBuf.functionArgument(name: name, space: space)
        let arg = self.buffersAndBytesContainer.addBuffer(buf,
                                                          argument: argument)
        
        checkForSameNames(name: arg.name)
        separateShaderArguments.append(arg)
        addedArgumentBuffers.append((argBuf, arg.index))
        return resourcesUsages.addToKernel(argBuf: argBuf, resources: resources, stages: self.stages)
    }
    mutating func buffer<T>(_ container: MTLBufferContainer<T>,
                            offset: MetalBinding<Int>,
                            index: Int){
        let buff = Buffer(container: container, offset: offset, index: index)
        checkIfBufferIsNew(buf: buff,
                           argumentName: String(describing: container))
        self.buffersAndBytesContainer.buffers.append(buff)
    }
    mutating func buffer<T>(_ container: MTLBufferContainer<T>,
                              offset: MetalBinding<Int>,
                              argument: MetalBufferArgument){
        let buf = Buffer(container: container, offset: offset, index: 0)
        
        checkIfBufferIsNew(buf: buf,
                           argumentName: argument.name)
        checkForSameNames(name: argument.name)
        
        let arg = self.buffersAndBytesContainer.addBuffer(buf,
                                                          argument: argument)
        self.separateShaderArguments.append(arg)
    }
    mutating func bytes<T>(_ binding: MetalBinding<T>, index: Int){
        let bytes = Bytes(binding: binding, index: index)
        self.buffersAndBytesContainer.bytes.append(bytes)
    }
    mutating func bytes<T>(_ binding: MetalBinding<T>,
                  argument: MetalBytesArgument){
        checkForSameNames(name: argument.name)
        let bytes = Bytes(binding: binding, index: 0)
        let arg = self.buffersAndBytesContainer.addBytes(bytes, argument: argument)
        
        self.separateShaderArguments.append(arg)
    }
    mutating func uniforms(_ uniforms: UniformsContainer, name: String?){
        self.uniforms.append(uniforms)
        let argument = MetalBytesArgument(uniformsContainer: uniforms, name: name)
        checkForSameNames(name: argument.name)
        let bytes = RawBytes(binding: uniforms.pointerBinding,
                             length: uniforms.length,
                             index: 0)
        let arg = self.buffersAndBytesContainer.addBytes(bytes, argument: argument)
        self.separateShaderArguments.append(arg)
    }
    mutating func texture(_ container: MTLTextureContainer, index: Int){
        let tex = Texture(container: container, index: index)
        checkIfTextureIsNew(container: container,
                            argumentName: String(describing: container))
        self.texturesContainer.textures.append(tex)
    }
    mutating func texture(_ container: MTLTextureContainer,
                  argument: MetalTextureArgument){
        checkIfTextureIsNew(container: container,
                            argumentName: argument.name)
        var argument = argument
        argument.textureType = container.descriptor.type
        let tex = Texture(container: container, index: 0)
        let arg = self.texturesContainer.add(tex, argument: argument)
        checkForSameNames(name: arg.name)
        self.separateShaderArguments.append(arg)
    }
    mutating func drawable(argument: MetalTextureArgument)->Int{
        var argument = argument
        argument.textureType = .type2D
        let arg = self.texturesContainer.add(nil, argument: argument)
        checkForSameNames(name: arg.name)
        self.separateShaderArguments.append(arg)
        return arg.index
    }
}
