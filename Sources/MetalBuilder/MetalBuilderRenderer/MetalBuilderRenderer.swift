import MetalKit
import SwiftUI

public enum MetalBuilderRendererError: Error{
    case noCommandBuffer
}

extension MetalBuilderRendererError: LocalizedError{
    public var errorDescription: String?{
        switch self {
        case .noCommandBuffer:
            "No Command Buffer for!"
        }
    }
}

public final class MetalBuilderRenderer{
    
    var renderData: RenderData!
    
    unowned var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    
    var commandBuffer: MTLCommandBuffer!
    
    let timer = MetalBuilderTimer()
    
    //depthStencilTexture of the MTKView (if there is any)
    var depthStencilTexture: MTLTexture?
    
//    var currentRenderPassEncoder: MetalRenderPassEncoderContainer?
}

extension MetalBuilderRenderer{
    func getCommandBuffer()->MTLCommandBuffer{
        self.commandBuffer
    }
    func startEncode() throws -> MTLCommandBuffer{
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else{
            throw MetalBuilderRendererError
                .noCommandBuffer
        }
        return commandBuffer
    }
    func endEncode(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable?){
        
//        self.currentRenderPassEncoder?.encoder?.endEncoding()
        
        if let drawable = drawable{
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()

        commandBuffer.waitUntilCompleted()
    }
    func restartEncode(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable?) throws{
        endEncode(commandBuffer: commandBuffer, drawable: drawable)
        self.commandBuffer = try startEncode()
    }
}

public extension MetalBuilderRenderer{
    
    convenience init(renderInfo: GlobalRenderInfo,
                     librarySource: String = "",
                     helpers: String = "",
                     options: MetalBuilderCompileOptions = .default,
                     setupFunction: (()->())? = nil,
                     startupFunction: ((MTLDevice)->())? = nil,
                     @MetalResultBuilder renderingContent: MetalBuilderContent) throws{
        try self.init(renderInfo: renderInfo,
                  librarySource: librarySource,
                  helpers: helpers,
                  options: options,
                  renderingContent: renderingContent,
                  setupFunction: setupFunction,
                  startupFunction: startupFunction)
        
    }
    
    convenience init(renderInfo: GlobalRenderInfo,
                     librarySource: String,
                     helpers: String,
                     options: MetalBuilderCompileOptions = .default,
                     @MetalResultBuilder renderingContent: MetalBuilderContent,
                     setupFunction: (()->())?,
                     startupFunction: ((MTLDevice)->())?) throws{
        
        self.init()
        
        self.device = renderInfo.device
        self.commandQueue = device.makeCommandQueue()
        
        let context = MetalBuilderRenderingContext(commandQueue: commandQueue)
        context.timer = timer
        
        do{
        
            renderData = try RenderData(from: renderingContent,
                                        librarySource: librarySource,
                                        helpers: helpers,
                                        options: options,
                                        context: context,
                                        renderInfo: renderInfo,
                                        setupFunction: setupFunction,
                                        startupFunction: startupFunction)
            
        }catch{
            fatalError(error.localizedDescription) 
        }
    }
    func draw(drawable: CAMetalDrawable?,
              renderPassDescriptor: MTLRenderPassDescriptor) throws{
       
        commandBuffer = try startEncode()
        
        timer.count()
        renderData.context.time = timer.time
        
        for pass in renderData.passes{
            
//            if let renderPass = pass as? RenderPass{
//                let passRenderEncoder = renderPass.component.renderableData.passRenderEncoder
//                if passRenderEncoder === currentRenderPassEncoder{
//
//                }else{
//                    currentRenderPassEncoder?.encoder?.endEncoding()
//                    currentRenderPassEncoder = passRenderEncoder
//                }
//            }
            
            let passInfo = MetalPassInfo(getCommandBuffer: getCommandBuffer,
                                         drawable: drawable, depthStencilTexture: depthStencilTexture,
                                         renderPassDescriptor: renderPassDescriptor){
                try self.restartEncode(commandBuffer: self.commandBuffer,
                                       drawable: nil)
            }
            
            try pass.encode(passInfo: passInfo)
                
        }

        endEncode(commandBuffer: commandBuffer, drawable: drawable)
        
        renderData.context.firstFrame = false
    }
    func setScaleFactor(_ sf: CGFloat){
        renderData.context.setScaleFactor(sf)
    }
    func setSize(size: CGSize){
        renderData.setViewport(size: size, device: device)
    }
    func setDepthStencilTexture(_ texture: MTLTexture?){
        depthStencilTexture = texture
    }
    
    func pauseTime(){
        timer.backgroundPause()
    }
    func resumeTime(){
        timer.backgroundResume()
    }
}

public extension MetalBuilderRenderer{
    func encode(commandBuffer: MTLCommandBuffer,
                depthTexture: MTLTexture?,
                renderPassDescriptor: MTLRenderPassDescriptor) throws{
        
        self.commandBuffer = commandBuffer
        
        for pass in renderData.passes{
            
            let passInfo = MetalPassInfo(getCommandBuffer: getCommandBuffer,
                                         drawable: nil,
                                         depthStencilTexture: depthTexture,
                                         renderPassDescriptor: renderPassDescriptor){
                try self.restartEncode(commandBuffer: self.commandBuffer,
                                       drawable: nil)
            }
            
            try pass.encode(passInfo: passInfo)
                
        }
    }
}
