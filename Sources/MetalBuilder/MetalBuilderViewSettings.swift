
import SwiftUI
import MetalKit

public struct MetalBuilderViewSettings{
    public init(depthPixelFormat: MTLPixelFormat? = nil,
                clearDepth: Double? = nil,
                stencilPixelFormat: MTLPixelFormat? = nil,
                clearStencil: UInt32? = nil,
                depthStencilAttachmentTextureUsage: MTLTextureUsage? = nil,
                depthStencilStorageMode: MTLStorageMode? = nil,
                clearColor: MTLClearColor? = nil,
                framebufferOnly: Bool? = nil,
                preferredFramesPerSecond: Int? = nil,
                sampleCount: Int? = nil) {
        self.depthPixelFormat = depthPixelFormat
        self.stencilPixelFormat = stencilPixelFormat
        self.clearDepth = clearDepth
        self.clearStencil = clearStencil
        self.depthStencilAttachmentTextureUsage = depthStencilAttachmentTextureUsage
        self.depthStencilStorageMode = depthStencilStorageMode
        self.clearColor = clearColor
        self.framebufferOnly = framebufferOnly
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.sampleCount = sampleCount
    }
    var depthPixelFormat: MTLPixelFormat?
    var clearDepth: Double?
    var stencilPixelFormat: MTLPixelFormat?
    var clearStencil: UInt32?
    
    var depthStencilAttachmentTextureUsage: MTLTextureUsage?
    var depthStencilStorageMode: MTLStorageMode?
    
    var clearColor: MTLClearColor?
    
    var framebufferOnly: Bool?
    var preferredFramesPerSecond: Int?
    
    var sampleCount: Int?
}

extension MetalBuilderViewSettings{
    func apply(toView view: MTKView){
        
        if let preferredFramesPerSecond = self.preferredFramesPerSecond{
            view.preferredFramesPerSecond = preferredFramesPerSecond
        }
        
        if let framebufferOnly = self.framebufferOnly{
            view.framebufferOnly = framebufferOnly
        }
       
        if let clearColor = self.clearColor{
            view.clearColor = clearColor
        }
        
        //Depth routine
        if let depthPixelFormat = self.depthPixelFormat{
            view.depthStencilPixelFormat = depthPixelFormat
        }
        if let clearDepth = self.clearDepth{
            view.clearDepth = clearDepth
        }
        //Stencil routine
        if let stencilPixelFormat = self.stencilPixelFormat{
            view.depthStencilPixelFormat = stencilPixelFormat
        }
        if let clearStencil = self.clearStencil{
            view.clearStencil = clearStencil
        }
        if let depthStencilAttachmentTextureUsage = self.depthStencilAttachmentTextureUsage{
            view.depthStencilAttachmentTextureUsage = depthStencilAttachmentTextureUsage
        }
        if #available(iOS 16.0, macOS 13.0, *){
            if let depthStencilStorageMode = self.depthStencilStorageMode{
                view.depthStencilStorageMode = depthStencilStorageMode
            }
        }
        if let sampleCount = self.sampleCount{
            view.sampleCount = sampleCount
        }
    }
}
