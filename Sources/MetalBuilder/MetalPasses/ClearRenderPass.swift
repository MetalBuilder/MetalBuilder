
import MetalKit

class ClearRenderPass: MetalPass{
    
    let component: ClearRender
    
    var libraryContainer: LibraryContainer?
    
    init(_ component: ClearRender){
        self.component = component
    }
    
    func setup(renderInfo: GlobalRenderInfo) throws{
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
        
        let (desc, _) = passInfo.getRenderPassDescriptorAndViewport(renderableData: component.renderableData)
        
        let renderPassEncoder = passInfo.getCommandBuffer()
            .makeRenderCommandEncoder(descriptor: desc)
        
        renderPassEncoder?.endEncoding()
    }
}
