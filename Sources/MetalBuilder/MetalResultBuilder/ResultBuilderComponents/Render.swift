import MetalKit
import SwiftUI

enum RenderComponentError: Error{
    case noSource(String)//label
    case noVertexShader(String)//label
    case noFragmentShader(String)//label
    case indexBufferElementType(String) // shader name
}

extension RenderComponentError: LocalizedError{
    public var errorDescription: String?{
        switch self {
        case .noSource(let label):
            "Render component \(label) received no source!"
        case .noVertexShader(let label):
            "Render component \(label) received no vertex shader!"
        case .noFragmentShader(let label):
            "Render component \(label) received no fragment shader!"
        case .indexBufferElementType(let string):
            "Index buffer's element type for \(string) should be UInt32 of UInt16!"
        }
    }
}

public typealias AdditionalEncodeClosureForRender = (MTLRenderCommandEncoder)->()
public typealias AdditionalPiplineSetupClosureForRender = (MTLRenderPipelineState)->()
public typealias PiplineSetupClosureForRender = (MTLDevice, MTLLibrary)->(MTLRenderPipelineState)

func fragmentNameFromLabel(_ label: String) -> String{
    "\(label)FragmentShader"
}
func vertexNameFromLabel(_ label: String) -> String{
    "\(label)VertexShader"
}

/// The component for rendering primitives.
///
/// With this component you render points, triangles and lines on the screen.
/// (This is a wrapper for `.drawPrimitives` and `.drawIndexedPrimitives` of `MTLRenderPassEncoder`.)
/// You pass textures and buffers to the vertex or fragment functions
/// using modifiers like `.vertexTexture`, `.fragmentBuffer`, ect.
/// The uniforms containers are passed to both vertex and fragment functions via the single `.uniforms` modifier.
/// The Metal source code for the functions should be either provided in the `librarySource` parameter
/// of the init of `MetalBuilderView`, or via the `.source` modifier:
/// ```
///     MetalBuilderView(){
///         Render()
///             .vertexBuffer(particles) //passed a buffer to the vertex shader
///             .fragmentTexture(imageTexture) //passed a texture to the fragment shader
///             .uniforms(uniforms) //passed uniforms to both shaders
///             .source("""
///             ...//Your Metal shaders here
///             """)
///             .fragmentBytes($myParameter) //passed a value to the fragment shader
///     }
/// ```
/// You can also use the `FragmentShader` and `VertexShader` structs
/// to have more modularity in configuring your shaders.
/// Note that you may pass objects to the shaders directly or through the Render component:
/// ```
///     MetalBuilderView(){
///         Render()
///             .vertexShader(myVertexShader
///                 .buffer(particles) //a buffer passed directly to the vertex shader
///             )
///             .fragmentShader(myFragmentShader
///                 .texture(imageTexture) //a texture passed directly to the fragment shader
///                 .uniforms(myUniformsForFragment) //uniforms passed directly
///                                                  //to the fragment shader
///             )
///             .uniforms(uniforms) //uniforms passed to both shaders
///                                 //through the Render component
///             .fragmentBytes($myParameter) //a value passed to the fragment shader
///                                          //through the Render component
///     }
/// ```
public struct Render: MetalBuilderComponent, Renderable {
    
    var label: String
    
    var source: String?
    
    var type: MTLPrimitiveType!
    var vertexOffset: MetalBinding<Int> = .constant(0)
    var vertexCount: MetalBinding<Int> = .constant(0)
    
    var vertex_id: IndexType = .uint
    var instance_id: IndexType = .uint
    
    var indexCount: MetalBinding<Int> = MetalBinding<Int>.constant(0)
    var indexBufferOffset: MetalBinding<Int> = .constant(0)
    var indexedPrimitives = false
    
    var instanceCount: MetalBinding<Int>?
    
    var additionalEncodeClosure: MetalBinding<AdditionalEncodeClosureForRender>?
    var additionalPiplineSetupClosure: MetalBinding<AdditionalPiplineSetupClosureForRender>?
    var piplineSetupClosure: MetalBinding<PiplineSetupClosureForRender>?
    
    var indexBuf: BufferProtocol?
    
    var vertexShader: VertexShader?
    var fragmentShader: FragmentShader?
    
    public var renderableData = RenderableData()
    
    func getLibrarySource() throws -> String{
        if let source{ return source }
        guard let vertexShader
        else{
            throw RenderComponentError.noVertexShader(label)
        }
        guard let fragmentShader
        else{
            throw RenderComponentError.noFragmentShader(label)
        }
        let (vertSource, vertexOut) = try vertexShader
            .librarySourceAndVertexOut(label: label)
        let frgSource = try fragmentShader
            .librarySource(label: label,
                           vertexOut: vertexOut)
        
        return """
               \(vertSource)
               \(frgSource)
               """
    }
    
    mutating func setup() throws -> (ArgumentsData, String){
        //vertex_id type based on index buffer type
        if let indexBuf{
            switch indexBuf.elementType{
            case is UInt32.Type: vertex_id = .uint
            case is UInt16.Type: vertex_id = .ushort
            default:
                throw RenderComponentError
                    .indexBufferElementType(label)
            }
        }
        let source = try getLibrarySource()
        addVertexArguments(source)
        addFragmentArguments(source)
        
        guard let vertexShader
        else{
            throw RenderComponentError.noVertexShader(label)
        }
        guard let fragmentShader
        else{
            throw RenderComponentError.noFragmentShader(label)
        }
        
        var argData = try vertexShader
            .argumentsContainer
            .getData(metalFunction: .vertex(vertexNameFromLabel(label)))
        let argData1 = try fragmentShader
            .argumentsContainer
            .getData(metalFunction: .fragment(fragmentNameFromLabel(label)))
        argData.appendContents(of: argData1)
        return (argData, source)
    }
    
    mutating func addVertexArguments(_ source: String){
        
        let vertexArgumentsDict: [String: MetalFunctionArgument] =
        [
            "instance_id"   : .custom("\(instance_id) instance_id [[instance_id]]"),
            "vertex_id"     : .custom("\(vertex_id) vertex_id [[vertex_id]]"),
        ]
        for arg in vertexArgumentsDict{
            if isThereIdentifierInCode(code: source,
                                       identifier: arg.key){
                self.vertexShader!
                    .argumentsContainer
                    .separateShaderArguments
                    .append(arg.value)
            }
        }
    }
    mutating func addFragmentArguments(_ source: String){
        
        let fragmentArgumentsDict: [String: MetalFunctionArgument] =
        [
            "primitive_id"   : .custom("uint primitive_id [[primitive_id]]"),
            "point_coord"   : .custom("float2 point_coord [[point_coord]]")
        ]
        for arg in fragmentArgumentsDict{
            if isThereIdentifierInCode(code: source,
                                       identifier: arg.key){
                self.fragmentShader!
                    .argumentsContainer
                    .separateShaderArguments
                    .append(arg.value)
            }
        }
    }
    
    public init(_ label: String,
                //vertex: String="", fragment: String="",
                type: MTLPrimitiveType = .triangle,
                offset: MetalBinding<Int> = .constant(0),
                count: MetalBinding<Int>,
                //source: String="",
                instanceCount: MetalBinding<Int>? = nil,
                renderableData: RenderableData = RenderableData()){
        
        if label == ""{
            fatalError("Label for Render shouldn't be empty!")
        }
        
        self.label = label
        
//        self.vertexFunc = vertex
//        self.fragmentFunc = fragment
        
        //self.librarySource = source
        
        self.type = type
        self.vertexOffset = offset
        self.vertexCount = count
        self.renderableData = renderableData
        self.instanceCount = instanceCount
        
        //Properties with didSet logic
        defer {
        }
    }
    
    public init<T>(_ label: String,
                   //vertex: String="", fragment: String="",
                   type: MTLPrimitiveType = .triangle,
                   indexBuffer: MTLBufferContainer<T>,
                   indexOffset: MetalBinding<Int> = .constant(0),
                   indexCount: MetalBinding<Int>, 
//                   source: String="",
                   instanceCount: MetalBinding<Int>? = nil,
                   renderableData: RenderableData = RenderableData()){
        if label == ""{
            fatalError("Label for Render shouldn't be empty!")
        }
        self.label = label
        self.indexBuf = Buffer(container: indexBuffer, offset: .constant(0), index: 0)
        
//        self.vertexFunc = vertex
//        self.fragmentFunc = fragment
        
//        self.librarySource = source
        
        self.type = type
        
        self.indexCount = indexCount
        self.indexBufferOffset = indexOffset
        self.indexedPrimitives = true
        self.renderableData = renderableData
        
        self.instanceCount = instanceCount
        
        //Properties with didSet logic
        defer {
        }
    }
}

// Misc modifiers for Render
public extension Render{
    func vertex(_ vertexShader: VertexShader) -> Render{
        var r = self
        r.vertexShader = vertexShader
        return r
    }
    func fragment(_ fragmentShader: FragmentShader) -> Render{
        var r = self
        r.fragmentShader = fragmentShader
        return r
    }
    /// The modifier for passing the source code of vertex and fragment shaders to a Render component
    /// - Parameter source: The String containing the code
    /// - Returns: The Render component with the added source code.
    ///
    /// The source code should obey the following structure:
    /// - 1. declaration of the vertex shader's output C-structure
    /// - 2. vertex shader implementation
    /// - 3. fragment shader implementation
    /// The first two or the last one should be ommited in case you are planning
    /// to pass the respective code using `.vertexShader`  or`.fragmentShader` modifiers.
    /// If you need to declare the output type for fragment shader declare it in `helpers` or consider using dedicated ``FragmentShader``.
    func source(_ source: String)->Render{
        var r = self
        r.source = source
        return r
    }
    func instanceCount(_ count: MetalBinding<Int>)->Render{
        var r = self
        r.instanceCount = count
        return r
    }
    /// Modifier for setting a closure for pipeline setup for Render component.
    /// - Parameter closureBinding: MetalBinding to a closure for pipeline setup logic.
    /// - Returns: Render component with the added custom pipeline setup logic.
    ///
    /// Use this modifier if you want to create MTLRenderPipelineState manually.
    func pipelineSetup(_ closureBinding: MetalBinding<PiplineSetupClosureForRender>)->Render{
        var r = self
        r.piplineSetupClosure = closureBinding
        return r
    }
    /// Modifier for setting a closure for pipeline setup for Render component.
    /// - Parameter closure: closure for custom pipeline setup logic.
    /// - Returns: Render component with the added custom pipeline setup logic.
    ///
    /// Use this modifier if you want to create MTLRenderPipelineState manually.
    func pipelineSetup(_ closure: @escaping PiplineSetupClosureForRender)->Render{
        self.pipelineSetup(MetalBinding<PiplineSetupClosureForRender>.constant(closure))
    }
    /// Modifier for setting a closure for additional pipeline setup for Render component.
    /// - Parameter closureBinding: MetalBinding to a closure for additional pipeline setup logic.
    /// - Returns: Render component with the added additional pipeline setup logic.
    ///
    /// The closure provided in this modifier will run after all the internal pipeline setup logic is performed.
    func additionalPipelineSetup(_ closureBinding: MetalBinding<AdditionalPiplineSetupClosureForRender>)->Render{
        var r = self
        r.additionalPiplineSetupClosure = closureBinding
        return r
    }
    /// Modifier for setting a closure for additional pipeline setup for Render component.
    /// - Parameter closure: closure for additional pipeline setup logic.
    /// - Returns: Render component with the added additional pipeline setup logic.
    ///
    /// The closure provided in this modifier will run after all the internal pipeline setup logic is performed.
    func additionalPipelineSetup(_ closure: @escaping AdditionalPiplineSetupClosureForRender)->Render{
        self.additionalPipelineSetup( MetalBinding<AdditionalPiplineSetupClosureForRender>.constant(closure))
    }
    /// Modifier for setting additional encode closure for Render component.
    /// - Parameter closureBinding: MetalBinding to a closure for additional encode logic.
    /// - Returns: Render component with the added additional encode logic.
    ///
    /// The closure provided in this modifier will run after all the internal encoding is performed
    /// right before the dispatch or before encoding of the next component.
    func additionalEncode(_ closureBinding: MetalBinding<AdditionalEncodeClosureForRender>)->Render{
        var r = self
        r.additionalEncodeClosure = closureBinding
        return r
    }
    /// Modifier for setting additional encode closure for Render component.
    /// - Parameter closure: Closure for additional encode logic.
    /// - Returns: Render component with the added additional encode logic.
    ///
    /// The closure provided in this modifier will run after all the internal encoding is performed
    /// right before the dispatch or before encoding of the next component.
    func additionalEncode(_ closure: @escaping AdditionalEncodeClosureForRender)->Render{
        self.additionalEncode(MetalBinding<AdditionalEncodeClosureForRender>.constant(closure))
    }
    func indexTypes(instance:  IndexType = .ushort,
                    vertex:    IndexType = .ushort//ignored with indexed render
                    )->Render{
        var r = self
        r.instance_id = instance
        r.vertex_id = vertex
        return r
    }
}

