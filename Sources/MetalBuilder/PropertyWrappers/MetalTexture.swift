
import SwiftUI
import MetalKit

@propertyWrapper
public final class MetalTexture{
    public var wrappedValue: MTLTextureContainer
    
    public init(wrappedValue: MTLTextureContainer){
        self.wrappedValue = wrappedValue
    }
    
    public init(_ descriptor: TextureDescriptor){
        self.wrappedValue = MTLTextureContainer(descriptor)
    }
}

enum MetalBuilderTextureError: Error {
case textureNotCreated, noDescriptor, descriptorSizeContainsZero
}

public final class MTLTextureContainer{
    public var descriptor: TextureDescriptor
    public var texture: MTLTexture?
    
    init(_ descriptor: TextureDescriptor){
        self.descriptor = descriptor
    }
    
    func create(device: MTLDevice,
                viewportSize: simd_uint2,
                pixelFormat: MTLPixelFormat?) throws{
        
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
        guard let texture = device.makeTexture(descriptor: mtlDescriptor)
        else{
            throw MetalBuilderTextureError
                .textureNotCreated
        }
        self.texture = texture
    }
}

enum TextureSize{
case fixed(CGSize), fromViewport(Double)
}

enum TexturePixelFormat{
case fixed(MTLPixelFormat), fromDrawable
}

public struct TextureDescriptor{
    var descriptor = MTLTextureDescriptor()
    var size: TextureSize? = nil
    var pixelFormat: TexturePixelFormat? = nil
    
    public init() {}
    
    mutating func mtlTextureDescriptor(viewportSize: simd_uint2 = [0,0],
                                       drawablePixelFormat: MTLPixelFormat? = nil)->MTLTextureDescriptor?{
        let d = descriptor
        //Determine size
        var s: (Int, Int)?
        if size == nil{ size = .fromViewport(1) }
        switch size! {
        case .fixed(let size): s = (Int(size.width), Int(size.height))
        case .fromViewport(let scale):
            s = (Int(Double(viewportSize.x)*scale),
                 Int(Double(viewportSize.y)*scale))
        }
        guard let size = s
        else{ return nil }
        d.width = size.0
        d.height = size.1
        
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
        descriptor.textureType = type
        return self
    }
    func usage(_ usage: MTLTextureUsage) -> TextureDescriptor {
        descriptor.usage = usage
        return self
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
        d.size = .fixed(size)
        return d
    }
    func sizeFromViewport(scaled: Double = 1) -> TextureDescriptor {
        var d = self
        d.size = .fromViewport(scaled)
        return d
    }
}
