
import MetalKit
import SwiftUI

public enum MetalBuilderRenderPassError: Error{
    case noRenderEncoder(String),
         textureIsNil(Int, String),
         noIndexBuffer(String),
         badIndexBuffer(String)
}

extension MetalBuilderRenderPassError: LocalizedError{
    public var errorDescription: String?{
        switch self {
        case .noRenderEncoder(let label):
            "Couldn't create render encoder for \(label)!"
        case .textureIsNil(let index, let shaderName):
            "Texture \(index) is nil for \(shaderName)!"
        case .noIndexBuffer(let label):
            "No index buffer provided for \(label)!"
        case .badIndexBuffer(let label):
            "Elements of the index buffer for \(label) is of wrong type. Should be UInt32 or UInt16!"
        }
    }
}

//Render Pass
final class RenderPass: MetalPass{
    
    var libraryContainer: LibraryContainer?
    
    var component: Render
    
    var renderPiplineState: MTLRenderPipelineState!
    
    var indexType: MTLIndexType = .uint16
    
    init(_ component: Render, libraryContainer: LibraryContainer){
        self.component = component
        self.libraryContainer = libraryContainer
    }
    func setup(renderInfo: GlobalRenderInfo) throws{

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        
        //depth and stencil routine
        if let depthStencilState = self.component.renderableData.depthStencilState{
            depthStencilState.create(device: renderInfo.device)
        }
        if let depthPixelFormat = renderInfo.depthPixelFormat{
            renderPipelineDescriptor.depthAttachmentPixelFormat = depthPixelFormat
        }
        //Override global depth pixel format with the one from depth attachment texture
        if let pixelFormat = component.renderableData.passDepthAttachment?.texture?.descriptor.pixelFormat{
            if case let .fixed(depthPixelFormat) = pixelFormat{
                renderPipelineDescriptor.depthAttachmentPixelFormat = depthPixelFormat
            }
        }
        if let stencilPixelFormat = renderInfo.stencilPixelFormat{
            renderPipelineDescriptor.stencilAttachmentPixelFormat = stencilPixelFormat
        }
        //Override global stencil pixel format with the one from stencil attachment texture
        if let pixelFormat = component.renderableData.passStencilAttachment?.texture?.descriptor.pixelFormat{
            if case let .fixed(stencilPixelFormat) = pixelFormat{
                renderPipelineDescriptor.stencilAttachmentPixelFormat = stencilPixelFormat
            }
        }
        
        //Pipeline Color Attachments
        for (id, pipelinDesc) in component.renderableData.pipelineColorAttachments{
            renderPipelineDescriptor.colorAttachments[id] = pipelinDesc
        }
        
        for (id, passDesc) in component.renderableData.passColorAttachments{
            if renderPipelineDescriptor.colorAttachments[id].pixelFormat.rawValue == 0,
               case let .fixed(pixelFormat) = passDesc.texture?.descriptor.pixelFormat{
                let pipelinDesc = MTLRenderPipelineColorAttachmentDescriptor()
                pipelinDesc.pixelFormat = pixelFormat
                renderPipelineDescriptor.colorAttachments[id] = pipelinDesc
            }
        }
        
        if renderPipelineDescriptor.colorAttachments[0].pixelFormat.rawValue == 0{
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = renderInfo.pixelFormat
        }
        
        if let sampleCount = component.sampleCount{
            renderPipelineDescriptor.rasterSampleCount = sampleCount
        }
        
        if let piplineSetupClosure = component.piplineSetupClosure?.wrappedValue{
            renderPiplineState = piplineSetupClosure(renderInfo.device, libraryContainer!.library!)
        }else{
            let vertexFunction = libraryContainer!.library!
                .makeFunction(name: vertexNameFromLabel(component.label))!
            let fragmentFunction = libraryContainer!.library!
                .makeFunction(name: fragmentNameFromLabel(component.label))!
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPiplineState =
            try renderInfo.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            
            try component.vertexShader!
                .argumentsContainer
                .createArgumentBuffers(device: renderInfo.device,
                                       mtlFunction: vertexFunction)
            try component.fragmentShader!
                .argumentsContainer
                .createArgumentBuffers(device: renderInfo.device,
                                       mtlFunction: fragmentFunction)
            
        }
        libraryContainer = nil
        
        if component.indexedPrimitives{
            if let buf = component.indexBuf{
                indexType = try getIndexType(buf.elementType)
                try buf.create(device: renderInfo.device)
            }else{
                throw MetalBuilderRenderPassError.noIndexBuffer(component.label)
            }
        }
        
        //Additional pipeline setup logic
        if let additionalPiplineSetupClosure = component.additionalPiplineSetupClosure?.wrappedValue{
            additionalPiplineSetupClosure(renderPiplineState)
        }
    }
    func prerun(renderInfo: GlobalRenderInfo) throws {
        component.vertexShader!.argumentsContainer.prerun()
        component.fragmentShader?.argumentsContainer.prerun()
    }
    func makeEncoder(passInfo: MetalPassInfo) throws -> MTLRenderCommandEncoder{
        let commandBuffer = passInfo.getCommandBuffer()
        guard let createdRenderPassEncoder = commandBuffer
            .makeRenderCommandEncoder(renderableData: component.renderableData,
                                      passInfo: passInfo)
        else{
            throw MetalBuilderRenderPassError
                .noRenderEncoder(component.label)
        }
        return createdRenderPassEncoder
    }
    
    func encode(passInfo: MetalPassInfo) throws {
        
        let encoderIsExternal: Bool
        let renderPassEncoder: MTLRenderCommandEncoder
    
        // render encoder external (passed in RenderableData) or internal
        if let externalEncoder = component.renderableData.passRenderEncoder{
            encoderIsExternal = true
            if let encoder = externalEncoder.encoder{
                renderPassEncoder = encoder
            }else{
                renderPassEncoder = try makeEncoder(passInfo: passInfo)
                externalEncoder.encoder = renderPassEncoder
            }
        }else{
            encoderIsExternal = false
            renderPassEncoder = try makeEncoder(passInfo: passInfo)
        }
        
        renderPassEncoder.configure(renderableData: component.renderableData, passInfo: passInfo)
        
        renderPassEncoder.setRenderPipelineState(renderPiplineState)
        
        //Set Buffers
        for buffer in component
            .vertexShader!
            .argumentsContainer
            .buffersAndBytesContainer
            .buffers{
            renderPassEncoder.setVertexBuffer(buffer.mtlBuffer,
                                              offset: buffer.offset.wrappedValue,
                                              index: buffer.index)
        }
        for buffer in component
            .fragmentShader!
            .argumentsContainer
            .buffersAndBytesContainer
            .buffers{
            renderPassEncoder.setFragmentBuffer(buffer.mtlBuffer,
                                                offset: buffer.offset.wrappedValue,
                                                index: buffer.index)
        }
        //Set Bytes
        for bytes in component
            .vertexShader!
            .argumentsContainer
            .buffersAndBytesContainer
            .bytes{
            bytes.encode{ pointer, length, index in
                renderPassEncoder.setVertexBytes(pointer, length: length, index: index)
            }
        }
        for bytes in component
            .fragmentShader!
            .argumentsContainer
            .buffersAndBytesContainer
            .bytes{
            bytes.encode{ pointer, length, index in
                renderPassEncoder.setFragmentBytes(pointer, length: length, index: index)
            }
        }
        //Set Textures
        for tex in component
            .vertexShader!
            .argumentsContainer
            .texturesContainer
            .textures{
            guard let texture = tex.container.texture
            else{
                throw MetalBuilderRenderPassError
                    .textureIsNil(tex.index, vertexNameFromLabel(component.label))
            }
            renderPassEncoder.setVertexTexture(texture, index: tex.index)
        }
        for tex in component
            .fragmentShader!
            .argumentsContainer
            .texturesContainer
            .textures{
            guard let texture = tex.container.texture
            else{
                throw MetalBuilderRenderPassError
                    .textureIsNil(tex.index, fragmentNameFromLabel(component.label))
            }
            renderPassEncoder.setFragmentTexture(texture, index: tex.index)
        }
        
        //Use Resources
        for resourceUsage in component.fragmentShader?
            .argumentsContainer
            .resourcesUsages
            .allResourcesUsages ?? []{
            renderPassEncoder.useResource(resourceUsage.resource.mtlResource,
                                          usage: resourceUsage.usage,
                                          stages: resourceUsage.stages ?? .fragment)
        }
        for resourceUsage in component.vertexShader!
            .argumentsContainer
            .resourcesUsages
            .allResourcesUsages{
            renderPassEncoder.useResource(resourceUsage.resource.mtlResource,
                                          usage: resourceUsage.usage,
                                          stages: resourceUsage.stages ?? .vertex)
        }
        
        //Use Heaps
        if let fragmentShader = component.fragmentShader{
            renderPassEncoder.useHeaps(
                fragmentShader
                    .argumentsContainer
                    .resourcesUsages
                    .allHeapsUsed.compactMap{ $0.heap }
                ,stages: .fragment
            )
        }
        
        renderPassEncoder.useHeaps(
            component
                .vertexShader!
                .argumentsContainer
                .resourcesUsages
                .allHeapsUsed.compactMap{ $0.heap }
            ,stages: .vertex
        )
        
        if let additionalEncodeClosure = component.additionalEncodeClosure?.wrappedValue{
            additionalEncodeClosure(renderPassEncoder)
        }
        
        if component.indexedPrimitives{
            if let instanceCount = component.instanceCount{
                renderPassEncoder.drawIndexedPrimitives(type: component.type,
                                                        indexCount: component.indexCount.wrappedValue,
                                                        indexType: indexType,
                                                        indexBuffer: component.indexBuf!.mtlBuffer!,
                                                        indexBufferOffset: component.indexBufferOffset.wrappedValue,
                                                        instanceCount: instanceCount.wrappedValue)
            }else{
                renderPassEncoder.drawIndexedPrimitives(type: component.type,
                                                        indexCount: component.indexCount.wrappedValue,
                                                        indexType: indexType,
                                                        indexBuffer: component.indexBuf!.mtlBuffer!,
                                                        indexBufferOffset: component.indexBufferOffset.wrappedValue)
            }
        }else{
            if let instanceCount = component.instanceCount{
                renderPassEncoder
                    .drawPrimitives(type: component.type,
                                    vertexStart: component.vertexOffset.wrappedValue,
                                    vertexCount: component.vertexCount.wrappedValue,
                                    instanceCount: instanceCount.wrappedValue)
            }else{
                renderPassEncoder
                    .drawPrimitives(type: component.type,
                                    vertexStart: component.vertexOffset.wrappedValue,
                                    vertexCount: component.vertexCount.wrappedValue)
            }
        }
        
        if !encoderIsExternal || component.renderableData.lastPass.wrappedValue{
            renderPassEncoder.endEncoding()
            component.renderableData.passRenderEncoder?.encoder = nil
        }
    }
    func getIndexType(_ indexType: Any.Type) throws ->MTLIndexType{
        
        if indexType == UInt32.self{
            return .uint32
        }
        if indexType == UInt16.self{
            return .uint16
        }
        
        throw MetalBuilderRenderPassError
            .badIndexBuffer(component.label)

    }
}


