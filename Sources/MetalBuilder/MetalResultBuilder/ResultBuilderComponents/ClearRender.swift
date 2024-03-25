import Metal
import SwiftUI

/// The render pass that clears a texture.
///
/// Pass the texture to clear and the color with Renderable protocol modifiers.
/// if no texture is passed the drawable of the view will be cleared.
/// Keep in mind that usually several drawables are created for the view.
/// You should clear them all to avoid flickering or other artifacts.
/// To clear all the drawables the ClearRender component should be active for several frames.
public struct ClearRender: MetalBuilderComponent, Renderable{
    
    let label: String
    
    public var renderableData = RenderableData()
    
    public init(_ label: String){
        self.label = label
    }
}
