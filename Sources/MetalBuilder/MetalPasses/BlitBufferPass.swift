import MetalKit
import SwiftUI

// BlitBuffer pass
class BlitBufferPass: MetalPass{
    
    var libraryContainer: LibraryContainer?
    
    let component: BlitBuffer
    
    init(_ component: BlitBuffer){
        self.component = component
    }
    func setup(renderInfo: GlobalRenderInfo){
    }
    func encode(passInfo: MetalPassInfo) throws {
        let commandBuffer = passInfo.getCommandBuffer()
        
        guard let inBuffer = component.inBuffer
        else{
            print("BlitBuffer: no inBuffer!")
            return
        }
        guard let outBuffer = component.outBuffer
        else{
            print("BlitBuffer: no outBuffer!")
            return
        }
        let elementSize = inBuffer.elementSize
        
        let size: Int
        if let c = component.count{
            size = c.wrappedValue*elementSize
        }else{
            size = inBuffer.mtlBuffer!.length// * elementSize
        }
        
        let inOffset = inBuffer.offset.wrappedValue*elementSize
        let outOffset = outBuffer.offset.wrappedValue*elementSize

        let blitBufferEncoder = commandBuffer.makeBlitCommandEncoder()
        blitBufferEncoder?.copy(from: inBuffer.mtlBuffer!, sourceOffset: inOffset,
                                to: outBuffer.mtlBuffer!, destinationOffset: outOffset,
                                size: size)
        blitBufferEncoder?.endEncoding()
    }
}
