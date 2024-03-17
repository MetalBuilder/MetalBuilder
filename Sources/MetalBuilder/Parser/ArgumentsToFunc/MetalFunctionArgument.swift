
import Foundation
import Metal

enum MetalBuilderFunctionArgumentsError: Error {
case bufferArgumentError(String), 
     textureArgumentError(String),
     noIndex(String)// name
}

public enum MetalFunctionArgument{
    case texture(MetalTextureArgument),
         buffer(MetalBufferArgument),
         bytes(MetalBytesArgument),
         
         custom(String)
    
    func string() throws -> String{
        switch self{
        case .texture(let arg):
            return try arg.string()
        case .buffer(let arg):
            return try arg.string()
        case .bytes(let arg):
            return try arg.string()
        case .custom(let string): 
            return string
        }
    }
    var index: Int{
        switch self{
        case .texture(let arg): return arg.index!
        case .buffer(let arg): return arg.index!
        case .bytes(let arg): return arg.index!
        case .custom: return -1 // no index for custom
        }
    }
    var name: String{
        switch self{
        case .texture(let arg): return arg.name
        case .buffer(let arg): return arg.name
        case .bytes(let arg): return arg.name
        case .custom: return "custom"
        }
    }
}

/// Texture argument descriptor that you use to pass texture containers to Compute and Render components.
///
/// Typically you use a texture argument to tell MetalBuilder to create a Metal declaration for your shader:
///```
///Compute("myComputeKernel")
///      .texture(inTexture,
///               argument: .init(type: "float", access: "read", name: "in"))
///      .texture(outTexture,
///               argument: .init(type: "float", access: "write", name: "out"))
///```
public struct MetalTextureArgument{
    let type: String
    var textureType: MTLTextureType?=nil
    let access: String
    let name: String
    var index: Int?
    var forArgBuffer: Bool
    var arrayOfTexturesCount: Int?
    func string() throws -> String{
        var prefix = ""
        switch textureType!{
        case .type2D: prefix = "texture2d"
        case .type2DArray: prefix = "texture2d_array"
        case .type1D: prefix = "texture1d"
        case .type1DArray: prefix = "texture1d_array"
        case .type2DMultisample: prefix = "texture2d_ms"
        case .type2DMultisampleArray: prefix = "texture2d_ms_array"
        case .typeCube: prefix = "texturecube"
        case .typeCubeArray: prefix = "texturecube_array"
        case .type3D: prefix = "texture3d"
        //case .typeTextureBuffer: prefix = ""
        //case .none: prefix = ""
        //case .some(_): prefix =
        default: throw MetalBuilderFunctionArgumentsError
                .textureArgumentError("Unsupported texture type: "+String(describing: textureType))
        }
        guard let index
        else{
            throw  MetalBuilderFunctionArgumentsError
                .noIndex(name)
        }
        let base: String
        if let arrayOfTexturesCount{
            base = "array<\(prefix)<\(type), access::\(access)>, \(arrayOfTexturesCount)>"
        }else{
            base = "\(prefix)<\(type), access::\(access)>"
        }
        
        if forArgBuffer{
            return "\(base) \(name) [[id(\(index))]]"
        }else{
            return "\(base) \(name) [[texture(\(index))]]"
        }
        
    }
    /// Creates a texture argument.
    /// - Parameters:
    ///   - type: The metal type of the pixels of the texture.
    ///   - access: The access attribute for the texture.
    ///   - name: The name of the variable by which the texture is passed to a shader.
    ///   - index: index of the texture in the shader declaration.
    /// If nil, the index will be set automatically by MetalBuilder.
    /// (Once you pass nil for the index of a texture argument of a component,
    /// avoid passing non-nil values in texture arguments of the same component.)
    public init(type: String, access: String, name: String, index: Int?=nil,
                forArgBuffer: Bool = false, arrayOfTexturesCount: Int? = nil) {
        self.type = type
        self.access = access
        self.name = name
        self.index = index
        self.forArgBuffer = forArgBuffer
        self.arrayOfTexturesCount = arrayOfTexturesCount
    }
}

public struct MetalBufferArgument{
    let space: String
    var type: String?
    let name: String
    var index: Int?
    var forArgBuffer: Bool
    
    let passAs: PassBufferToMetal
    let count: Int?
    
    let swiftType: Any.Type
    var swiftTypeToMetal: SwiftTypeToMetal{
        SwiftTypeToMetal(swiftType: swiftType,
                         metalType: type)
    }
    var metalDeclaration: MetalTypeDeclaration?{
        let type = swiftTypeToMetal
        return metalTypeDeclaration(from: type.swiftType,
                                    name: type.metalType)
    }
    func string() throws -> String{
        guard let index
        else{
            throw  MetalBuilderFunctionArgumentsError
                .noIndex(name)
        }
        if forArgBuffer{
            return "\(space) \(type!)\(passAs.prefix) \(name) [[id(\(index))]]"
        }else{
            return  "\(space) \(type!)\(passAs.prefix) \(name) [[buffer(\(index))]]"
        }
    }
    init(swiftType: Any.Type, space: String, type: String?, name: String, index: Int?,
         passAs: PassBufferToMetal, count: Int?,
         forArgBuffer: Bool) {
        self.space = space
        self.type = type
        self.name = name
        self.index = index
        self.swiftType = swiftType
        self.passAs = passAs
        self.count = count
        self.forArgBuffer = forArgBuffer
    }
    init<T>(_ container: MTLBufferContainer<T>,
            space: String, type: String?, name: String?, index: Int?,
            forArgBuffer: Bool=false) throws{
        
        var t: String?
        if let type = metalType(for: T.self){
            t = type
        }
        if let type = container.metalType{
            t = type
        }
        if let type = type{
            t = type
        }
        
//        guard t != nil
//        else {
//            throw MetalBuilderFunctionArgumentsError
//                .bufferArgumentError("No Metal type for buffer!")
//        }
        
        var n: String?
        if let name = container.metalName{
            n = name
        }
        if let name = name{
            n = name
        }
        guard let name = n
        else {
            throw MetalBuilderFunctionArgumentsError
                .bufferArgumentError("No Metal name for buffer!")
        }

        self.init(swiftType: T.self, space: space, type: t, name: name, index: index,
                  passAs: container.passAs, count: container.count,
                  forArgBuffer: forArgBuffer)
    }
}

public struct MetalBytesArgument{
    let space: String
    var type: String?
    let name: String
    var index: Int?
    var forArgBuffer: Bool
    let swiftType: Any.Type
    var metalDeclaration: MetalTypeDeclaration?{
        if let decl = _metalDeclaration{
            return decl
        }else{
            let type = swiftTypeToMetal
            return metalTypeDeclaration(from: type.swiftType,
                                        name: type.metalType)
        }
    }
    var _metalDeclaration: MetalTypeDeclaration?
    var swiftTypeToMetal: SwiftTypeToMetal{
        SwiftTypeToMetal(swiftType: swiftType,
                         metalType: type)
    }
    func string() throws -> String{
        guard let index
        else{
            throw  MetalBuilderFunctionArgumentsError
                .noIndex(name)
        }
        if forArgBuffer{
            return "\(space) \(type!)& \(name) [[id(\(index))]]"
        }else{
            return "\(space) \(type!)& \(name) [[buffer(\(index))]]"
        }
    }
    init(swiftType: Any.Type, space: String, type: String?, name: String, 
         index: Int?=nil, metalDeclaration: MetalTypeDeclaration?=nil,
         forArgBuffer: Bool) {
        self.swiftType = swiftType
        self.space = space
        self.type = type
        self.name = name
        self.index = index
        
        self._metalDeclaration = metalDeclaration
        self.forArgBuffer = forArgBuffer
    }
    init<T>(binding: MetalBinding<T>, space: String, 
            type: String?=nil, name: String?=nil, index: Int?=nil,
            forArgBuffer: Bool=false){
        var n: String
        if let name = name {
            n = name
        }else{
            n = binding.metalName!
        }
        var t: String?
        if let type = type {
            t = type
        }else{
            t = binding.metalType
        }
        
        self.init(swiftType: T.self, space: space, type: t, name: n, index: index,
                  forArgBuffer: forArgBuffer)
    }
    init(uniformsContainer: UniformsContainer, name: String?){
        let type = uniformsContainer.metalType
        let metalDeclaration = uniformsContainer.metalDeclaration
        let metalName: String
        if let name = name{
            metalName = name
        }else{
            metalName = uniformsContainer.metalName!
        }
        self.init(swiftType: Any.self, space: "constant",
                  type: type, name: metalName, metalDeclaration: metalDeclaration,
                  forArgBuffer: false)
    }
}
