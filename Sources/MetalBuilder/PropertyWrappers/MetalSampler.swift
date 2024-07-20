
import SwiftUI
import MetalKit
/*
/// Declares a state for a MTLSamplerState object
@propertyWrapper
public final class MetalSampler{
    public var wrappedValue: MTLSamplerStateContainer
    
    public var projectedValue: MetalSampler{
        self
    }
    
    public init(wrappedValue: MTLSamplerStateContainer){
        self.wrappedValue = wrappedValue
    }
    
    public init(){
        self.wrappedValue = MTLSamplerStateContainer()
    }
    /// Creates an instance of MetalSampler property wrapper.
    public init(_ descriptor: SamplerDescriptor){
        self.wrappedValue = MTLSamplerStateContainer()
    }
}

public struct SamplerDescriptor{
    var count: Int?
    var metalType: String?
    var metalName: String?
    
    var passAs: PassBufferToMetal = .pointer
    
    var bufferOptions: MTLResourceOptions = .init()

    public init(){
    }
}
*/
public final class MTLSamplerStateContainer{//}: MTLResourceContainer{
    
    internal var argBufferInfo = ArgBufferInfo()
    internal var dataType: MTLDataType = .sampler
    
    public init(){}
    
    public var sampler: MTLSamplerState?{
        didSet {
            //updateResourceInArgumentBuffers()
        }
    }
    
    //weak var device: MTLDevice?
    
    public var metalName: String?
    
//    init(count: Int? = nil, metalName: String? = nil) {
//        self.metalName = metalName
//    }
}
/*
extension MTLSamplerStateContainer{
    var mtlResource: MTLResource{
        sampler!
    }
    func updateResource(argBuffer: ArgumentBuffer, id: Int, offset: Int){
        //argBuffer.encoder!.setBuffer(self.buffer, offset: offset, index: id)
        //print("updated buffer resource [\(id)] in \(argBuffer.name)")
    }
}
*/

