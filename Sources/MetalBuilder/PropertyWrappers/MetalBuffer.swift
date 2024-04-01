
import SwiftUI
import MetalKit

public enum PassBufferToMetal{
    case pointer,
         structReference(String), // type name
         singleReference
    var prefix: String{
        switch self {
        case .pointer:
            "*"
        case .structReference:
            "&"
        case .singleReference:
            "&"
        }
    }
    var isStructReference: Bool{
        if case .structReference = self {
            true
        }else{
            false
        }
    }
    var structName: String?{
        if case let .structReference(structName) = self {
            structName
        }else{
            nil
        }
    }
    func referenceStructDecl(type: String, count: Int) -> String{
        if case let .structReference(structName) = self {
            """
            struct \(structName){
                \(type) array[\(count)];
            };
            """
        }else{
            ""
        }
    }
}

/// Declares a state for a MTLBuffer object
///
/// metalType and metalName - supposed type and name for the buffer in MSL code
@propertyWrapper
public final class MetalBuffer<T>{
    public var wrappedValue: MTLBufferContainer<T>
    
    public var projectedValue: MetalBuffer<T>{
        self
    }
    
    public init(wrappedValue: MTLBufferContainer<T>){
        self.wrappedValue = wrappedValue
    }
    /// Creates an instance of MetalBuffer property wrapper.
    /// - Parameters:
    ///   - count: size of the buffer, i.e. buffer elements count.
    ///   - metalType: type that will be used to address this buffer in Metal library code.
    ///   - metalName: name that will be used to address this buffer in Metal library code.
    ///   - options: buffer options.
    ///   - fromArray: an array to copy elements from it to the buffer or `nil` to init the buffer with zeroes.
    public init(count: Int? = nil,
                metalType: String? = nil,
                metalName: String? = nil,
                options: MTLResourceOptions = .init(),
                fromArray: [T]? = nil,
                passAs: PassBufferToMetal = .pointer){
        self.wrappedValue = MTLBufferContainer<T>(count: count,
                                                  metalType: metalType,
                                                  metalName: metalName,
                                                  options: options,
                                                  fromArray: fromArray,
                                                  passAs: passAs)
    }
    /// Creates an instance of MetalBuffer property wrapper.
    /// - Parameters:
    ///   - descriptor: descriptor of the buffer to be created.
    ///   - fromArray: an array to copy elements from it to the buffer or `nil` to init the buffer with zeroes.
    public init(_ descriptor: BufferDescriptor, fromArray: [T]? = nil){
        self.wrappedValue = MTLBufferContainer<T>(count: descriptor.count,
                                                  metalType: descriptor.metalType,
                                                  metalName: descriptor.metalName,
                                                  options: descriptor.bufferOptions,
                                                  fromArray: fromArray,
                                                  passAs: descriptor.passAs)
    }
}

public struct BufferDescriptor{
    var count: Int?
    var metalType: String?
    var metalName: String?
    
    var passAs: PassBufferToMetal = .pointer
    
    var bufferOptions: MTLResourceOptions = .init()

    public init(count: Int? = nil,
                metalType: String? = nil,
                metalName: String? = nil,
                options: MTLResourceOptions = .init(),
                passAs: PassBufferToMetal = .pointer){
        self.count = count
        self.metalName = metalName
        self.metalType = metalType
        
        self.bufferOptions = options
        self.passAs = passAs
    }
}
public extension BufferDescriptor{
    func passAs(_ p: PassBufferToMetal) -> BufferDescriptor {
        var d = self
        d.passAs = p
        return d
    }
    func count(_ n: Int) -> BufferDescriptor {
        var d = self
        d.count = n
        return d
    }
    func metalName(_ name: String) -> BufferDescriptor {
        var d = self
        d.metalName = name
        return d
    }
    func metalType(_ type: String) -> BufferDescriptor {
        var d = self
        d.metalType = type
        return d
    }
    func options(_ options: MTLResourceOptions) -> BufferDescriptor {
        var d = self
        d.bufferOptions = options
        return d
    }
}

enum MetalBuilderBufferError: Error {
case bufferNotCreated
}

public class BufferContainer: MTLResourceContainer{
    
    internal var argBufferInfo = ArgBufferInfo()
    internal var dataType: MTLDataType = .pointer
    
    public var buffer: MTLBuffer?{
        didSet {
            updateResourceInArgumentBuffers()
        }
    }
    
    public var count: Int? { 0 }
    
    public var elementSize: Int?
    
    public var metalType: String?
    public var metalName: String?
    
    init(count: Int? = nil, metalType: String? = nil, metalName: String? = nil) {
        self.metalType = metalType
        self.metalName = metalName
    }
    
    func createBufferProtocolConformingBuffer() -> BufferProtocol!{
        nil
    }
}

extension BufferContainer{
    var mtlResource: MTLResource{
        buffer!
    }
    func updateResource(argBuffer: ArgumentBuffer, id: Int, offset: Int){
        argBuffer.encoder!.setBuffer(self.buffer, offset: offset, index: id)
        print("updated buffer resource [\(id)] in \(argBuffer.name)")
    }
}

/// Container class for MTLBuffer
///
/// You can access it's content on CPU through 'pointer'
public final class MTLBufferContainer<T>: BufferContainer{

    public var pointer: UnsafeMutablePointer<T>?
    
    weak var device: MTLDevice?
    
    public var bufferOptions: MTLResourceOptions = .init()
    
    var fromArray: [T]?
    
    var passAs: PassBufferToMetal!
    
    public override var count: Int?{
        get {
            _count
        }
        set {
            _count = newValue
        }
    }
    
    private var _count: Int?
    
    private var manual: Bool!
    
    public init(count: Int? = nil, metalType: String? = nil, metalName: String? = nil,
                options: MTLResourceOptions = .init(),
                fromArray: [T]? = nil,
                passAs: PassBufferToMetal = .pointer,
                manual: Bool = false){
        super.init()
        self.metalType = metalType
        self.metalName = metalName
        self._count = count
        self.manual = manual
        
        self.bufferOptions = options
        
        self.fromArray = fromArray
        if self.count == nil{
            if let fromArray{
                self.count = fromArray.count
            }
        }
        self.passAs = passAs
    }
    
    // called on startup for each buffer that added to some component
    func initialize(device: MTLDevice) throws{
        if manual{
            return
        }else{
            try create(device: device)
        }
    }
    
    /// Creates a new buffer for the container.
    /// - Parameters:
    ///   - device: The GPU device that creates the buffer.
    ///   - count: Number of elements in the new buffer. Pass `nil` if you don't want it to be changed.
    ///   - fromArray: an array to copy elements from it to the buffer or `nil` to init the buffer with zeroes.
    ///
    /// Use this method in ManualEncode block if you need to recreate the buffer in the container
    public func create(device: MTLDevice, count: Int? = nil, fromArray: [T]? = nil) throws{
        
        self.device = device
        elementSize = MemoryLayout<T>.stride
        var count = count
        if count == nil {
            if fromArray == nil{
                count = self.count
            }
        }else{
            self._count = count
        }
        guard let count = count
        else{
            print("no count or array, skip creation!")
            return
        }
        
        self.count = count
        
        let array: [T]?
        if let fromArray{
            array = fromArray
        }else{
            array = self.fromArray
        }
        let length: Int
        if let array{
            length = elementSize! * count
            buffer = device.makeBuffer(bytes: array, length: length, options: bufferOptions)
            self.fromArray = nil
        }else{
            length = elementSize!*count
            buffer = device.makeBuffer(length: length, options: bufferOptions)
        }
        
        let cpuAccessible = ((bufferOptions.rawValue & MTLResourceOptions.storageModeShared.rawValue) != 0) ||
                            ((bufferOptions.rawValue & MTLResourceOptions.cpuCacheModeWriteCombined.rawValue) != 0) ||
                            (bufferOptions == .init()) // Seems like the empty option means "shared"
        
        if let buffer = buffer{
            //create the pointer to the buffer only if its created with a storage mode that allows to acces it from CPU
            if cpuAccessible{
                pointer = buffer.contents().bindMemory(to: T.self, capacity: length)
            }
            if let metalName{ buffer.label = metalName }
        }else{
            throw MetalBuilderBufferError
                .bufferNotCreated
        }
    }
    override func createBufferProtocolConformingBuffer() -> BufferProtocol{
        Buffer(container: self, offset: .constant(0), index: 0)
    }
}
//load and store data
public extension MTLBufferContainer{
    func getData(count: Int? = nil) -> Data?{
        elementSize = MemoryLayout<T>.stride
        var count = count
        if count == nil{
            count = self.count
        }
        
        guard let count, let elementSize, let buffer
        else{ return nil }
            
        let length = elementSize*count
        let data = Data(bytes: buffer.contents(), count: length)
        return data
    }
    
    func load(data: Data, count: Int? = nil, device: MTLDevice?=nil){
        elementSize = MemoryLayout<T>.stride
        var count = count
        if count == nil{
            count = self.count
        }
        
        var d = self.device
        if d == nil{
            d = device
        }
        
        guard let count, let elementSize, let d
        else{ return }
        
        let length = elementSize*count
        data.withUnsafeBytes{ bts in
            buffer = d.makeBuffer(bytes: bts.baseAddress!, length: length)!
            if let buffer = buffer{
                pointer = buffer.contents().bindMemory(to: T.self, capacity: length)
            }
        }
    }
}
