import MetalKit
import SwiftUI

public typealias MetalContent = (Binding<simd_uint2>)->MetalBuilderResult

public final class MetalBuilderRenderer{
    
    var commandQueue: MTLCommandQueue!
    var device: MTLDevice!
    
    var passes: [MetalPass] = []
    var textures: [MTLTextureContainer] = []
    
    var pixelFormat: MTLPixelFormat?
    
    @MetalState var viewportSize: simd_uint2 = [0, 0]
    
    public init(device: MTLDevice,
                librarySource: String = "",
                pixelFormat: MTLPixelFormat,
                @MetalResultBuilder metalContent: MetalContent,
                options: MTLCompileOptions? = nil) throws{
        
        self.device = device
        
        var librarySource = librarySource
        
        do{
        
            let result = metalContent($viewportSize)
        
            //init passes
            for component in result{
                if let computeComponent = component as? Compute{
                    passes.append(ComputePass(computeComponent))
                    addTextures(newTexs: computeComponent.textures.map{ $0.container })
                    try createBuffers(buffers: computeComponent.buffers)
                    
                    if librarySource != ""{
                        let kernel = MetalFunction.compute(computeComponent.kernel)
                        try addDeclaration(of: computeComponent.kernelArguments,
                                           toHeaderOf: kernel, in: &librarySource)
                    }
                }
                if let renderComponent = component as? Render{
                    passes.append(RenderPass(renderComponent))
                    addTextures(newTexs: renderComponent.vertexTextures.map{ $0.container })
                    addTextures(newTexs: renderComponent.fragTextures.map{ $0.container })
                    addTextures(newTexs: renderComponent.colorAttachments.values.map{ $0.texture })
                    try createBuffers(buffers: renderComponent.vertexBufs)
                    try createBuffers(buffers: renderComponent.fragBufs)
                    
                    if librarySource != ""{
                        let vertex = MetalFunction.vertex(renderComponent.vertexFunc)
                        try addDeclaration(of: renderComponent.vertexArguments,
                                           toHeaderOf: vertex, in: &librarySource)
                        let fragment = MetalFunction.fragment(renderComponent.fragmentFunc)
                        try addDeclaration(of: renderComponent.fragmentArguments,
                                           toHeaderOf: fragment, in: &librarySource)
                    }
                    
                }
                if let cpuCodeComponent = component as? CPUCode{
                    passes.append(CPUCodePass(cpuCodeComponent))
                }
                if let mpsUnaryComponent = component as? MPSUnary{
                    addTextures(newTexs: [mpsUnaryComponent.inTexture, mpsUnaryComponent.outTexture])
                    passes.append(MPSUnaryPass(mpsUnaryComponent))
                }
                if let blitTextureComponent = component as? BlitTexture{
                    addTextures(newTexs: [blitTextureComponent.inTexture, blitTextureComponent.outTexture])
                    passes.append(BlitTexturePass(blitTextureComponent))
                }
                if let blitBufferComponent = component as? BlitBuffer{
    //                try createBuffers(buffers: [blitBufferComponent.inBuffer!,
    //                                            blitBufferComponent.outBuffer!])
                    passes.append(BlitBufferPass(blitBufferComponent))
                }
            }
        
            //init Library
            self.pixelFormat = pixelFormat
            var library : MTLLibrary!

            if librarySource == ""{
                library = self.device.makeDefaultLibrary()
            }else{
                library = try self.device.makeLibrary(source: librarySource, options: options)
            }
            commandQueue =  self.device.makeCommandQueue()
            
            //setup passes
            for pass in passes{
                try pass.setup(device: device, library: library)
            }
            
            //create textures
            for tex in textures{
                try tex.create(device: device,
                               viewportSize: viewportSize,
                               pixelFormat: pixelFormat)
            }
            
        }catch{ print(error) }
    }
    
    //adds only unique textures
    func addTextures(newTexs: [MTLTextureContainer?]){
        let newTextures = newTexs.compactMap{ $0 }
            .filter{ newTexture in
                !textures.contains{ oldTexture in
                    newTexture === oldTexture
                }
            }
        textures.append(contentsOf: newTextures)
    }
    
    //creates only new buffers
    func createBuffers(buffers: [BufferProtocol]) throws{
        for buf in buffers{
            if buf.mtlBuffer == nil {
                try buf.create(device: device)
            }
        }
    }
    
    func draw(drawable: CAMetalDrawable) throws{
       
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else{
            print("no command buffer!")
            return
        }
        for pass in passes{
            try pass.encode(commandBuffer, drawable)
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()

        commandBuffer.waitUntilCompleted()
        
    }
    func setSize(size: CGSize){
        viewportSize = simd_uint2([UInt32(size.width), UInt32(size.height)])
        //create textures
        for tex in textures{
            if case .fromViewport = tex.descriptor.size{
                do{
                    try tex.create(device: device, viewportSize: viewportSize, pixelFormat: pixelFormat)
                }catch{ print(error) }
            }
        }
        
    }
}
