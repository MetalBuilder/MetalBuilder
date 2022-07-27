import MetalKit
import SwiftUI

// BlitBuffer pass
class BlitBufferPass: MetalPass{
    let component: BlitBuffer
    
    init(_ component: BlitBuffer){
        self.component = component
    }
    func setup(device: MTLDevice, library: MTLLibrary){
    }
    func encode(_ commandBuffer: MTLCommandBuffer,_ drawable: CAMetalDrawable?) {
        
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
        let elementSize = inBuffer.elementSize!
        let count: Int
        if let c = component.count{
            count = c
        }else{
            count = inBuffer.count
        }
        
        let size = count*elementSize
        let inOffset = component.sourceOffset*size
        let outOffset = component.destinationOffset*size

        let blitBufferEncoder = commandBuffer.makeBlitCommandEncoder()
        blitBufferEncoder?.copy(from: inBuffer.buffer!, sourceOffset: inOffset,
                                to: outBuffer.buffer!, destinationOffset: outOffset,
                                size: size)
        blitBufferEncoder?.endEncoding()
    }
}
