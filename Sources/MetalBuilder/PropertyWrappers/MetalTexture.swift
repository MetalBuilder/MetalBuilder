
import SwiftUI
import MetalKit

@propertyWrapper
public final class MetalTexture{
    public var wrappedValue: MTLTextureContainer
    
    public var projectedValue: MetalTexture{
        self
    }
    
    public init(wrappedValue: MTLTextureContainer){
        self.wrappedValue = wrappedValue
    }
    
    public init(_ descriptor: TextureDescriptor=TextureDescriptor().manual(),
                label: String?=nil,
                fromImage: ImageForTexture? = nil){
        self.wrappedValue = MTLTextureContainer(descriptor,
                                                label: label,
                                                fromImage: fromImage)
    }
}

enum MetalBuilderTextureError: Error {
case textureNotCreated, noDescriptor, descriptorSizeContainsZero,
    pixelFormatFromDrawable
}

public final class MTLTextureContainer{
    public var descriptor: TextureDescriptor
    public var label: String?
    public var texture: MTLTexture?{
        didSet{
            updateResourceInArgumentBuffers()
        }
    }
    var image: ImageForTexture?
    weak var device: MTLDevice?
    internal var argBufferInfo = ArgBufferInfo()
    internal var dataType: MTLDataType = .texture
    
    init(){
        descriptor = TextureDescriptor()
    }
    
    public init(_ descriptor: TextureDescriptor, label: String?=nil, fromImage: ImageForTexture? = nil){
        self.descriptor = descriptor
        self.image = fromImage
        self.label = label
    }
    
    //creates or loads the texture
    func initialize(device: MTLDevice,
                    viewportSize: simd_uint2,
                    pixelFormat: MTLPixelFormat?) throws{
        if !descriptor.manualCreation{
            if let image{
                self.device = device
                try loadImage(image)
            }else{
                try create(device: device,
                           viewportSize: viewportSize,
                           pixelFormat: pixelFormat)
            }
        }
    }
    
    public func create(device: MTLDevice, drawable: CAMetalDrawable, newDescriptor: TextureDescriptor?=nil) throws{
        if let desc = newDescriptor{
            self.descriptor = desc
        }
        try create(device: device,
               viewportSize: simd_uint2(x: UInt32(drawable.texture.width),
                                        y: UInt32(drawable.texture.height)),
               pixelFormat: drawable.texture.pixelFormat)
    }
    
    //pixel format should not be from drawable
    public func create(device: MTLDevice, mtlSize: MTLSize, pixelFormat: MTLPixelFormat?=nil) throws{
        self.descriptor.size = .fixed(mtlSize)
        if let pixelFormat{
            self.descriptor.pixelFormat = .fixed(pixelFormat)
        }else{
            if case .fromDrawable = self.descriptor.pixelFormat{
                throw MetalBuilderTextureError
                    .pixelFormatFromDrawable
            }
        }
        try create(device: device,
                   viewportSize: [0,0],
                   pixelFormat: .invalid)
    }
    
    func create(device: MTLDevice,
                viewportSize: simd_uint2,
                pixelFormat: MTLPixelFormat?) throws{
        //self.device = device
        guard let mtlDescriptor = descriptor.mtlTextureDescriptor(viewportSize: viewportSize, drawablePixelFormat: pixelFormat)
        else{
            throw MetalBuilderTextureError
                .noDescriptor
        }
        guard mtlDescriptor.width>0 && mtlDescriptor.height>0
        else{
            throw MetalBuilderTextureError
                .descriptorSizeContainsZero
        }
        mtlDescriptor.allowGPUOptimizedContents = true
        
        guard let texture = device.makeTexture(descriptor: mtlDescriptor)
        else{
            throw MetalBuilderTextureError
                .textureNotCreated
        }
        if let label{
            texture.label = label
        }
        self.texture = texture
    }
}

extension MTLTextureContainer: Equatable{
    public static func == (lhs: MTLTextureContainer, rhs: MTLTextureContainer) -> Bool {
        lhs === rhs
    }
}

extension MTLTextureContainer: MTLResourceContainer{
    var mtlResource: MTLResource{
        texture!
    }
    func updateResource(argBuffer: ArgumentBuffer, id: Int, offset: Int){
        argBuffer.encoder!.setTexture(self.texture, index: id)
        print("updated texture resource [\(id)] in \(argBuffer.name)")
    }
}

//load image
public extension MTLTextureContainer{
    func loadImage(_ image: ImageForTexture, newDescriptor: TextureDescriptor? = nil) throws{
        if let newDescriptor{
            self.descriptor = newDescriptor
        }
        try image.loadInto(texture: self)
    }
}

//load and store data
public extension MTLTextureContainer{
    func getData<T:SIMD >(type: T.Type, region: MTLRegion?=nil)->Data?{
        guard let texture
        else{ return nil }
        
        var region = region
        if region == nil{
            region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: texture.width,
                                             height: texture.height, depth: texture.depth))
        }
        let bytesPerRow = MemoryLayout<T>.size * region!.size.width
        let bytesPerImage = bytesPerRow*region!.size.height * region!.size.depth
        var array = [T](repeating: T.init(), count: bytesPerImage)
        array.withUnsafeMutableBytes{ bts in
            texture.getBytes(bts.baseAddress!,
                             bytesPerRow: bytesPerRow,
                             from: region!,
                             mipmapLevel: 0)
        }
        let data = Data(bytes: &array, count: bytesPerImage)
        return data
    }
    func load<T>(data: Data, type: T.Type, region: MTLRegion? = nil){
        var region = region
        if region == nil{
            region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: texture!.width,
                                             height: texture!.height, depth: texture!.depth))
        }
        let bytesPerRow = MemoryLayout<T>.size * region!.size.width
        data.withUnsafeBytes{ bts in
            texture!.replace(region: region!, mipmapLevel: 0,
                             withBytes: bts.baseAddress!, bytesPerRow: bytesPerRow)
        }
    }
}

public enum TextureSize{
case fixed(MTLSize), fromViewport(Double)
}

public enum TexturePixelFormat{
case fixed(MTLPixelFormat), fromDrawable
}

public struct TextureDescriptor{
    public var size: TextureSize? = nil
    public var pixelFormat: TexturePixelFormat? = nil
    
    public var type: MTLTextureType = .type2D
    public var arrayLength: Int = 1
    public var usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]
    
    public var storageMode: MTLStorageMode = .private
    
    public var mipmapLevelCount: Int = 1
    
    public var sampleCount: Int = 1
    
    var manualCreation = false
    
    public init() {}
    
    mutating func mtlTextureDescriptor(viewportSize: simd_uint2 = [0,0],
                                       drawablePixelFormat: MTLPixelFormat? = nil)->MTLTextureDescriptor?{
        
        let d = MTLTextureDescriptor()
        d.mipmapLevelCount = mipmapLevelCount
        d.textureType = type
        d.arrayLength = arrayLength
        d.usage = usage
        d.storageMode = storageMode
        d.sampleCount = sampleCount
        
        //Determine size
        var s: MTLSize?
        if size == nil{ size = .fromViewport(1) }
        switch size! {
        case .fixed(let size): s = size
        case .fromViewport(let scale):
            s = MTLSize(width: Int(Double(viewportSize.x)*scale),
                        height: Int(Double(viewportSize.y)*scale),
                        depth: 1)
        }
        guard let size = s
        else{ return nil }
        d.width = size.width
        d.height = size.height
        d.depth = size.depth
        
        //Determine PixelFormat
        var pf: MTLPixelFormat
        if pixelFormat == nil{ pixelFormat = .fromDrawable }
        switch pixelFormat!{
        case .fixed(let format): pf = format
        case .fromDrawable:
            guard let drawablePixelFormat = drawablePixelFormat
            else { return nil }
            pf = drawablePixelFormat
        }
        d.pixelFormat = pf
        return d
    }
}
public extension TextureDescriptor{
    func type(_ type: MTLTextureType) -> TextureDescriptor {
        var d = self
        d.type = type
        return d
    }
    func sampleCount(_ n: Int) -> TextureDescriptor {
        var d = self
        d.sampleCount = n
        return d
    }
    func arrayLength(_ n: Int) -> TextureDescriptor {
        var d = self
        d.arrayLength = n
        return d
    }
    func usage(_ usage: MTLTextureUsage) -> TextureDescriptor {
        var d = self
        d.usage = usage
        return d
    }
    func pixelFormat(_ pixelFormat: MTLPixelFormat) -> TextureDescriptor {
        var d = self
        d.pixelFormat = .fixed(pixelFormat)
        return d
    }
    func pixelFormatFromDrawable() -> TextureDescriptor {
        var d = self
        d.pixelFormat = .fromDrawable
        return d
    }
    func fixedSize(_ size: CGSize) -> TextureDescriptor {
        var d = self
        let mtlSize = MTLSize(width: Int(size.width), height: Int(size.height), depth: 1)
        d = fixedSize(mtlSize)
        return d
    }
    func fixedSize(_ mtlSize: MTLSize) -> TextureDescriptor {
        var d = self
        d.size = .fixed(mtlSize)
        return d
    }
    func sizeFromViewport(scaled: Double = 1) -> TextureDescriptor {
        var d = self
        d.size = .fromViewport(scaled)
        return d
    }
    func storageMode(_ storageMode: MTLStorageMode) -> TextureDescriptor {
        var d = self
        d.storageMode = storageMode
        return d
    }
    func mipmaps(_ mipmapLevelCount: Int) -> TextureDescriptor {
        var d = self
        d.mipmapLevelCount = mipmapLevelCount
        return d
    }
    func manual() -> TextureDescriptor {
        var d = self
        d.manualCreation = true
        return d
    }
}

public extension MTLTexture{
    var mtlSize: MTLSize{
        .init(width: self.width, height: self.height, depth: self.depth)
    }
}
