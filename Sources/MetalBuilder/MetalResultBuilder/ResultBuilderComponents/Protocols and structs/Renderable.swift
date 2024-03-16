import MetalKit
import SwiftUI


/// Protocol for MetalBuilder components that contain one or several renderpasses
///
/// The protocol declares one property `renderableData` that contains all the necessary information for the rendering pass,
/// such as color, depth, and stencil attachments.
/// Conforming to this protocol allows you to configure the component via chaining modifiers:
///  ```
///         MyComponent()
///             .toTexture(myTexture)
///  ```
///  All the modifications will be accumulated in 'renderableData' that you may pass consequently to the very basic
///  inbuild  ``Render`` component that is also conforming to this protocol:
///  ```
///  MyOwnMetalBuildingBlock: MetalBuildingBlock, Renderable{
///         var renderableData = RenderableData()
///         ...
///         var metalContent: MetalContent{
///             ...
///             Render(type: .triangle, count: vertexCount, renderableData: renderableData)
///               .stencilAttachment(stencilTexture,
///                                  loadAction: .clear,
///                                  storeAction: .store,
///                                  clearStencil: 0)
///               .vertexShader(...)
///               .fragmentShader(...)
///             ...
///         }
///         ...
///  }
///  ```
public protocol Renderable{
    var renderableData: RenderableData { get set }
}

//Modifiers for Renderable
public extension MetalBuilderComponent where Self: Renderable{
    /// Adds destination texture for a render pass of Renderable component.
    /// - Parameters:
    ///   - container: the destination texture
    ///   - index: attachement index for the texture
    ///
    /// if `nill` is passed and there are no other modifier with no-nil container,
    /// the drawable texture will be set as output.
    /// - Returns: The Renderable component with the applied descriptor.
    func toTexture(_ container: MTLTextureContainer?, index: Int = 0)->Self{
        var r = self
        if let container = container {
            var a: ColorAttachment
            if let aExistent = renderableData.passColorAttachments[index]{
                a = aExistent
            }else{
                a = ColorAttachment()
            }
            a.texture = container
            r.renderableData.passColorAttachments[index] = a
        }
        return r
    }
    /// Adds a depth stencil state to a Renderable component.
    /// - Parameters:
    ///   - descriptor: The depth and stencil descriptor to use in the rendering pass
    ///   - stencilReferenceValue: The stencil reference value for both front and back stencil comparison tests.
    /// that you create and configure by a Render component.
    /// - Returns: The Renderable component with the applied descriptor.
    func depthStencilState(_ state: MetalDepthStencilStateContainer, stencilReferenceValue: UInt32?=nil) -> Self{
        var r = self
        r.renderableData.depthStencilState = state
        r.renderableData.stencilReferenceValue = stencilReferenceValue
        return r
    }
    /// Adds a stencil attachment to the Renderable component.
    /// - Parameter attachement: Stencil attachment struct.
    /// - Returns: The Renderable component with the added stencil attachement.
    func stencilAttachment(_ attachement: StencilAttachment?) -> Self{
        var r = self
        r.renderableData.passStencilAttachment = attachement
        return r
    }
    /// Adds a stencil attachment to the Renderable component.
    /// - Parameters:
    ///   - texture: Texture to use in the attachement.
    ///   - loadAction: Binding to a load action value.
    ///   - storeAction: Binding to a store action value.
    ///   - clearStencil: Binding to a value to use when clearing the stencil attachment.
    /// - Returns: The Renderable component with the added stencil attachement.
    func stencilAttachment(texture: MTLTextureContainer? = nil,
                           loadAction: Binding<MTLLoadAction>? = nil,
                           storeAction: Binding<MTLStoreAction>? = nil,
                           clearStencil: Binding<UInt32>? = nil) -> Self{
        var r = self
        let stencilAttachment = StencilAttachment(texture: texture,
                                                  loadAction: loadAction,
                                                  storeAction: storeAction,
                                                  clearStencil: clearStencil)
        r.renderableData.passStencilAttachment = stencilAttachment
        return r
    }
    /// Adds a stencil attachment to the Renderable component.
    /// - Parameters:
    ///   - texture: Texture to use in the attachement.
    ///   - loadAction: Load action value.
    ///   - storeAction: Store action value.
    ///   - clearStencil: Value to use when clearing the stencil attachment.
    /// - Returns: The Renderable component with the added stencil attachement.
    func stencilAttachment(texture: MTLTextureContainer? = nil,
                          loadAction: MTLLoadAction? = nil,
                          storeAction: MTLStoreAction? = nil,
                          clearStencil: UInt32? = nil) -> Self{
        var _loadAction: Binding<MTLLoadAction>? = nil
        var _storeAction: Binding<MTLStoreAction>? = nil
        var _clearStencil: Binding<UInt32>? = nil
        if let loadAction = loadAction {
            _loadAction = Binding<MTLLoadAction>.constant(loadAction)
        }
        if let storeAction = storeAction {
            _storeAction = Binding<MTLStoreAction>.constant(storeAction)
        }
        if let clearStencil = clearStencil {
            _clearStencil = Binding<UInt32>.constant(clearStencil)
        }
        return stencilAttachment(texture: texture,
                                 loadAction: _loadAction,
                                 storeAction: _storeAction,
                                 clearStencil: _clearStencil)
    }
    /// Adds a depth attachment to the Renderable component.
    /// - Parameter attachement: Depth attachment struct.
    /// - Returns: The Renderable component with the added depth attachement.
    func depthAttachment(_ attachement: DepthAttachment?) -> Self{
        var r = self
        r.renderableData.passDepthAttachment = attachement
        return r
    }
    /// Adds a depth attachment to the Renderable component.
    /// - Parameters:
    ///   - texture: Texture to use in the attachement.
    ///   - loadAction: Binding to a load action value.
    ///   - storeAction: Binding to a store action value.
    ///   - clearStencil: Binding to a value to use when clearing the depth attachment.
    /// - Returns: The Renderable component with the added color attachement.
    func depthAttachment(texture: MTLTextureContainer? = nil,
                         loadAction: Binding<MTLLoadAction>? = nil,
                         storeAction: Binding<MTLStoreAction>? = nil,
                         clearDepth: Binding<Double>) -> Self{
        var r = self
        let depthAttachment = DepthAttachment(texture: texture,
                                              loadAction: loadAction,
                                              storeAction: storeAction,
                                              clearDepth: clearDepth)
        r.renderableData.passDepthAttachment = depthAttachment
        return r
    }
    /// Adds a depth attachment to the Renderable component.
    /// - Parameters:
    ///   - texture: Texture to use in the attachement.
    ///   - loadAction: Load action value.
    ///   - storeAction: Store action value.
    ///   - clearStencil: Value to use when clearing the depth attachment.
    /// - Returns: The Renderable component with the added depth attachement.
    func depthAttachment(texture: MTLTextureContainer? = nil,
                          loadAction: MTLLoadAction? = nil,
                          storeAction: MTLStoreAction? = nil,
                          clearDepth: Double = 1) -> Self{
        var _loadAction: Binding<MTLLoadAction>? = nil
        var _storeAction: Binding<MTLStoreAction>? = nil
        var _clearDepth: Binding<Double>
        if let loadAction = loadAction {
            _loadAction = Binding<MTLLoadAction>.constant(loadAction)
        }
        if let storeAction = storeAction {
            _storeAction = Binding<MTLStoreAction>.constant(storeAction)
        }
        //if let clearDepth = clearDepth {
            _clearDepth = Binding<Double>.constant(clearDepth)
        //}
        return depthAttachment(texture: texture,
                               loadAction: _loadAction,
                               storeAction: _storeAction,
                               clearDepth: _clearDepth)
    }
    /// Adds a color attachment to the Renderable component.
    /// - Parameters:
    ///   - index: Index of the color attachment. 0 if unspecified.
    ///   - texture: Texture to use in the attachement.
    ///   - loadAction: Binding to a load action value.
    ///   - storeAction: Binding to a store action value.
    ///   - clearColor: Binding to a clear color value (MTLClearColor).
    /// - Returns: The Renderable component with the added color attachement.
    ///
    /// If the texture for the attachement is ommited then the drawable texure will be used,
    /// unless the texture for this attachment is set with `toTexture` modifier.
    func colorAttachement(_ index: Int = 0,
                          texture: MTLTextureContainer? = nil,
                          loadAction: Binding<MTLLoadAction>? = nil,
                          storeAction: Binding<MTLStoreAction>? = nil,
                          mtlClearColor: Binding<MTLClearColor>? = nil) -> Self{
        var r = self
        //If texture for this attachment is already set (e.g. in toTexture modifier), then ignore nil
        var texture = texture
        if texture == nil{
            if let existingTexture = r.renderableData.passColorAttachments[index]?.texture{
                texture = existingTexture
            }
        }
        let colorAttachement = ColorAttachment(texture: texture,
                                               loadAction: loadAction,
                                               storeAction: storeAction,
                                               clearColor: mtlClearColor)
        r.renderableData.passColorAttachments[index] = colorAttachement
        return r
    }
    /// Adds the color attachment to a Renderable component.
    /// - Parameters:
    ///   - index: Index of the color attachment. 0 if unspecified.
    ///   - texture: Texture to use in the attachement.
    ///   - loadAction: Load action value.
    ///   - storeAction: Store action value.
    ///   - clearColor: Clear color value (MTLClearColor).
    /// - Returns: The Renderable component with the added color attachement.
    func colorAttachement(_ index: Int = 0,
                          texture: MTLTextureContainer? = nil,
                          loadAction: MTLLoadAction? = nil,
                          storeAction: MTLStoreAction? = nil,
                          mtlClearColor: MTLClearColor? = nil) -> Self{
        var _loadAction: Binding<MTLLoadAction>? = nil
        var _storeAction: Binding<MTLStoreAction>? = nil
        var _clearColor: Binding<MTLClearColor>? = nil
        if let loadAction = loadAction {
            _loadAction = Binding<MTLLoadAction>.constant(loadAction)
        }
        if let storeAction = storeAction {
            _storeAction = Binding<MTLStoreAction>.constant(storeAction)
        }
        if let clearColor = mtlClearColor {
            _clearColor = Binding<MTLClearColor>.constant(clearColor)
        }
        return colorAttachement(index,
                                texture: texture,
                                loadAction: _loadAction,
                                storeAction: _storeAction,
                                mtlClearColor: _clearColor)
    }
    /// Adds the color attachment to a Renderable component.
    /// - Parameters:
    ///   - index: Index of the color attachment. 0 if unspecified.
    ///   - texture: Texture to use in the attachement.
    ///   - loadAction: Load action value.
    ///   - storeAction: Store action value.
    ///   - clearColor: Clear color value (Color).
    /// - Returns: The Renderable component with the added color attachement.
    func colorAttachement(_ index: Int = 0,
                          texture: MTLTextureContainer? = nil,
                          loadAction: MTLLoadAction? = nil,
                          storeAction: MTLStoreAction? = nil,
                          clearColor: Color) -> Self{
        var _clearColor: MTLClearColor? = nil
        //if let color = clearColor{
            if let cgC = UIColor(clearColor).cgColor.components{
                _clearColor = MTLClearColor(red:   cgC[0],
                                            green: cgC[1],
                                            blue:  cgC[2],
                                            alpha: cgC[3])
            }else{
                print("Could not get color components for color: ", clearColor)
            }
        //}
        return colorAttachement(index,
                                texture: texture,
                                loadAction: loadAction,
                                storeAction: storeAction,
                                mtlClearColor: _clearColor)
    }
    /// Adds color attachments to a Renderable component.
    /// - Parameter attachments: The color attachements.
    /// - Returns:  The Render component with the added color attachements.
    func colorAttachements(_ attachments: [Int: ColorAttachment]) -> Self{
        var r = self
        r.renderableData.passColorAttachments = attachments
        return r
    }
    /// Adds the render pipeline color attachment to a Renderable component.
    /// - Parameter descriptor: The descriptor for the attachement to add.
    /// - Returns: The Render component with the added render pipeline color attachment.
    func pipelineColorAttachment(id: Int = 0, _ descriptor: MTLRenderPipelineColorAttachmentDescriptor?) -> Self{
        var r = self
        r.renderableData.pipelineColorAttachments[id] = descriptor
        return r
    }
    /// Adds the render pass command encoder to a Renderable component.
    /// - Parameter encoder: The descriptor for the attachement to add.
    /// - Returns: The Render component with the added render pass command encoder .
    func renderEncoder(_ encoder: MetalRenderPassEncoderContainer,
                       lastPass: MetalBinding<Bool> = .constant(false)) -> Self{
        var r = self
        r.renderableData.passRenderEncoder = encoder
        r.renderableData.lastPass = lastPass
        return r
    }
    func viewport(_ viewport: MetalBinding<MTLViewport>)->Self{
        var r = self
        r.renderableData.viewport = viewport
        return r
    }
    func depthBias(_ bias: MetalBinding<DepthBias>)->Self{
        var r = self
        r.renderableData.depthBias = bias
        return r
    }
    func depthBias(_ bias: DepthBias)->Self{
        return self.depthBias(MetalBinding.constant(bias))
    }
    func depthBias(_ depthBias: Float, slopeScale: Float, clamp: Float)->Self{
        let bias = DepthBias(depthBias: depthBias, slopeScale: slopeScale, clamp: clamp)
        return self.depthBias(bias)
    }
    func cullMode(_ cullMode: MetalBinding<CullMode>)->Self{
        var r = self
        r.renderableData.cullMode = cullMode
        return r
    }
    func cullMode(_ mtlCullMode: MTLCullMode, frontFacingWinding: MTLWinding?=nil)->Self{
        let cullMode = CullMode(mtlCullMode: mtlCullMode, frontFacingWinding: frontFacingWinding)
        return self.cullMode(MetalBinding<CullMode>.constant(cullMode))
    }
}
