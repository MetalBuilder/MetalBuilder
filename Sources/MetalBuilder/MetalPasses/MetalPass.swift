import MetalKit

protocol MetalPass{
    var libraryContainer: LibraryContainer? { get set }
    func setup(renderInfo: GlobalRenderInfo) throws
    func prerun(renderInfo: GlobalRenderInfo) throws
    func encode(passInfo: MetalPassInfo) throws
}
extension MetalPass{
    func prerun(renderInfo: GlobalRenderInfo) throws{
    }
}

public struct MetalPassInfo {
    public let getCommandBuffer: ()->MTLCommandBuffer
    public let drawable: CAMetalDrawable?
    let depthStencilTexture: MTLTexture?
    let renderPassDescriptor: MTLRenderPassDescriptor
    let restartEncode: () throws ->()
}
public extension MetalPassInfo{
    func getRenderPassDescriptorAndViewport(renderableData: RenderableData) -> (MTLRenderPassDescriptor, MTLViewport){
        let renderPassDescriptor = self.renderPassDescriptor
        
        //Configuring Render Pass Descriptor
        
        //color attachments
        for key in renderableData.passColorAttachments.keys{
            if let a = renderableData.passColorAttachments[key]{
                if a.texture == nil{
                    if key != 0{
                        let d = a.descriptor
                        d.texture = self.drawable?.texture
                        renderPassDescriptor.colorAttachments[key] = d
                    }else{
                        a.apply(
                            toDescriptor: renderPassDescriptor.colorAttachments[key]
                        )
                    }
                }else{
                    renderPassDescriptor.colorAttachments[key] = a.descriptor
                }
            }
        }
        
        //stencil attachment
        if let passStencilAttachment = renderableData.passStencilAttachment{
            renderPassDescriptor.stencilAttachment = passStencilAttachment.descriptor
        }else{
            renderPassDescriptor.stencilAttachment = MTLRenderPassStencilAttachmentDescriptor()
        }
        
        //depth attachment
        if let passDepthAttachment = renderableData.passDepthAttachment{
            let descriptor = passDepthAttachment.descriptor
            if descriptor.texture == nil{
                descriptor.texture = self.depthStencilTexture
            }
            renderPassDescriptor.depthAttachment = descriptor
        }
        
        //Viewport
        var viewport: MTLViewport
        if let vp = renderableData.viewport{
            viewport = vp.wrappedValue
        }else{
            var outTexture: MTLTexture
            if let t = renderPassDescriptor.colorAttachments[0].texture{
                outTexture = t
            }else{
                outTexture = drawable!.texture
            }
            
            viewport = MTLViewport(originX: 0.0, originY: 0.0,
                                   width:  Double(outTexture.width),
                                   height: Double(outTexture.height), znear: 0.0, zfar: 1.0)
        }
        
        return (renderPassDescriptor, viewport)
    }
}
