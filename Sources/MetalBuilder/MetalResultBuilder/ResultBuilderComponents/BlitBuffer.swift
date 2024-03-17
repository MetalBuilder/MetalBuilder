
import MetalKit
import SwiftUI

/// The component for copying buffers.
///
/// Use this component to copy memory between buffers on GPU.
/// Configure source, destination, count with modifiers.
public struct BlitBuffer: MetalBuilderComponent{
    
    var inBuffer: BufferProtocol?
    var outBuffer: BufferProtocol?
    
    var count: MetalBinding<Int>?
    
    public init(){
    }
}

// chaining dunctions
public extension BlitBuffer{
    func source<T>(_ container: MTLBufferContainer<T>,
                   offset: MetalBinding<Int>? = nil)->BlitBuffer{
        var b = self
        let offset = offset ?? .constant(0)
        let buffer = Buffer(container: container, offset: offset, index: 0)
        b.inBuffer = buffer
        return b
    }
    func destination<T>(_ container: MTLBufferContainer<T>,
                        offset: MetalBinding<Int>? = nil)->BlitBuffer{
        var b = self
        let offset = offset ?? .constant(0)
        let buffer = Buffer(container: container, offset: offset, index: 0)
        b.outBuffer = buffer
        return b
    }
    func count(_ count: MetalBinding<Int>)->BlitBuffer{
        var b = self
        b.count = count
        return b
    }
}
