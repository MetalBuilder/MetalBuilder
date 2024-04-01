
struct FunctionAndArguments{
    let function: MetalFunction
    var arguments: [MetalFunctionArgument]
}
extension FunctionAndArguments: Equatable{
    static func == (lhs: FunctionAndArguments, rhs: FunctionAndArguments) -> Bool {
        lhs.function == rhs.function
    }
}

public struct SwiftTypeToMetal{
    let swiftType: Any.Type
    let metalType: String?
}

func parse(library: inout String,
           funcArguments: [FunctionAndArguments]) throws{
    
    var funcArguments = funcArguments.noDublicates()
    var metalTypeNames: [String] = []
    var structDeclarations: String = ""
    var referenceStructsDecls: String = ""

    for funcAndArgID in funcArguments.indices{
        for argID in funcArguments[funcAndArgID].arguments.indices{
            let arg = funcArguments[funcAndArgID].arguments[argID]
            switch arg{
            case .buffer(let buf):
                func changeBufArgument(type: String){
                    var bufArg = buf
                    bufArg.type = type
                    let argNew: MetalFunctionArgument =
                        .buffer(bufArg)
                    funcArguments[funcAndArgID]
                        .arguments[argID] = argNew
                }
                let metalDeclaration = buf.metalDeclaration
                if let metalDeclaration{
                    if !metalTypeNames.contains(metalDeclaration.typeName) {
                        metalTypeNames.append(metalDeclaration.typeName)
                        structDeclarations += metalDeclaration.declaration
                    }
                        
                        if buf.type == nil{// add type name to function declaration if there was no type set in the component
                            changeBufArgument(type: metalDeclaration.typeName)
                        }
                }
                if let structName = buf.passAs.structName{
                    //add struct decl
                    
                    if !metalTypeNames.contains(structName) {
                        metalTypeNames.append(structName)
                        
                        let type = metalDeclaration?.typeName ?? buf.type
                        guard let type
                        else{
                            throw MetalBuilderParserError
                                .wrongType("No type for buffer: `\(buf.name)`")
                        }
                        
                        if let count = buf.count{
                            referenceStructsDecls += buf.passAs
                                .referenceStructDecl(type: type,
                                                     count: count)
                            
                        }else{
                            throw MetalBuilderParserError
                                .noCount("No count set for buffer: `\(buf.name)`. Fixed count is required for passing as fixed array in struct.")
                        }
                    }
                    
                    //change argument to struct
                    changeBufArgument(type: structName)
                }
            case .bytes(let bytes):
                func changeBytesArgument(type: String){
                    var bytesArg = bytes
                    bytesArg.type = type
                    let argNew: MetalFunctionArgument =
                        .bytes(bytesArg)
                    funcArguments[funcAndArgID]
                       .arguments[argID] = argNew
                }
                if let metalDeclaration = bytes.metalDeclaration{
                    if !metalTypeNames.contains(metalDeclaration.typeName) {
                        metalTypeNames.append(metalDeclaration.typeName)
                        structDeclarations += metalDeclaration.declaration
                    }
                    
                    if bytes.type == nil{// add type name to function declaration if there was no type set in the component
                        changeBytesArgument(type: metalDeclaration.typeName)
                    }
                }else{
                    if bytes.type == nil{// if no type provided trying to assess an ordinary type (float, int, ect.)
                        let swiftType = bytes.swiftType
                        
                        guard let metalType = metalType(for: swiftType) else {
                            throw MetalBuilderParserError
                                .wrongType("Bytes `" +
                                           bytes.name +
                                           "` for function `" +
                                           funcArguments[funcAndArgID].function.name +
                                           "` " +
                                           "are wrong type: "+String(describing: swiftType))
                        }
                        changeBytesArgument(type: metalType)
                    }
                }
            default: break
            }
       
        }
    }
    library = structDeclarations + referenceStructsDecls + library
    for funcAndArg in funcArguments {
        try addArgumentsDeclaration(of: funcAndArg.arguments,
                           toHeaderOf: funcAndArg.function, in: &library)
    }
    #if DEBUG
    print(library)
    #endif
}

extension Array where Element: Equatable{
    func noDublicates()->[Element]{
        var out: [Element] = []
        for f in self{
            if !out.contains(where: { $0 == f }){
                out.append(f)
            }
        }
        return out
    }
    mutating func appendUnique(_ element: Element){
        if !self.contains(where: { $0 == element}){
            self.append(element)
        }
    }
}

extension Array where Element == BufferProtocol{
    func noDublicates()->[Element]{
        var out: [Element] = []
        for f in self{
            if !out.contains(where: { $0 === f }){
                out.append(f)
            }
        }
        return out
    }
}
