import MetalKit
import SwiftUI

protocol BufferProtocol{
    var mtlBuffer: MTLBuffer? { get }
    var offset: MetalBinding<Int> { get }
    var index: Int { get set }
    
    var elementSize: Int { get }
    var count: Int { get }
    
    var elementType: Any.Type { get }
    var swiftTypeToMetal: SwiftTypeToMetal? { get }
    func create(device: MTLDevice) throws
    
    var id: UnsafeMutableRawPointer { get }
    
    var bContainer: BufferContainer{ get }
}

//extension BufferProtocol{
//    static func ==(lhr: any BufferProtocol, rhr: any BufferProtocol)->Bool{
//        lhr.id == rhr.id
//    }
//}

func ===(lhr: any BufferProtocol, rhr: any BufferProtocol)->Bool{
    lhr.id == rhr.id
}

struct Buffer<T>: BufferProtocol{
    static func == (lhs: Buffer<T>, rhs: Buffer<T>) -> Bool {
        lhs.id == rhs.id
    }
    
    let container: MTLBufferContainer<T>
    let offset: MetalBinding<Int>
    var index: Int
    
    var elementType: Any.Type{
        T.self
    }
    
    func create(device: MTLDevice) throws {
        try container.initialize(device: device)
    }
    
    var bContainer: BufferContainer{
        container
    }
    
    var mtlBuffer: MTLBuffer?{
        container.buffer
    }
    var count: Int{
        container.count!
    }
    var elementSize: Int{
        container.elementSize!
    }
    var swiftTypeToMetal: SwiftTypeToMetal?{
        if T.self is MetalStruct.Type{
            return SwiftTypeToMetal(swiftType: T.self,
                                    metalType: container.metalType)
        }else{
            return nil
        }
    }
    var id: UnsafeMutableRawPointer{
        container.id
    }
}

struct Texture{
    let container: MTLTextureContainer
    var index: Int
}

protocol BytesProtocol{
    var index: Int {get set}
    func encode(encoder: (UnsafeRawPointer, Int, Int)->())
}

struct RawBytes: BytesProtocol{
    let binding: Binding<UnsafeRawPointer?>
    let length: Int
    var index: Int

    func encode(encoder: (UnsafeRawPointer, Int, Int)->()){
        let value = binding.wrappedValue!
        encoder(value, length, index)
    }
}

struct Bytes<T>: BytesProtocol{
    let binding: MetalBinding<T>
    var index: Int
    
    func encode(encoder: (UnsafeRawPointer, Int, Int)->()){
        let value = binding.wrappedValue
        withUnsafeBytes(of: value){ pointer in
            encoder(pointer.baseAddress!,
                    MemoryLayout<T>.stride,
                    index)
        }
    }
}

