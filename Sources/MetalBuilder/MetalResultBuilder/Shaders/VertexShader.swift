
import SwiftUI

enum VertexShaderError: Error{
    case noVertexOut(String)//label
    case noBody(String)//label
}
extension VertexShaderError: LocalizedError{
    public var errorDescription: String?{
        switch self {
        case .noVertexOut(let label):
            "Vertex shader for \(label) has no VertexOut declaration!"
        case .noBody(let label):
            "Vertex shader for \(label) has no body!"
        }
    }
}

public struct VertexShader: ShaderProtocol{
    
    public var argumentsContainer = ArgumentsContainer(stages: .vertex)
    public var gridFit: GridFit?
    
    /// Creates the VertexShader
    public init(){
    }
    
    var vertexOutFields: String = ""
    
    public var _body: String?
    public var _source: String?
    
    func vertexOut(label: String) throws -> (String, String){//VertexOut (Type, decl)
        let vertexOut = "\(label)VertexOut"
        let decl = """
                   struct \(vertexOut){
                     \(vertexOutFields)
                   };
                   """
        return (vertexOut, decl)
    }
    
    func librarySourceAndVertexOut(label: String) throws -> (String, String?){
        if let _source{
            return (_source, getTypeFromFromStructDeclaration(_source))
        }
        guard let body = _body
        else{ 
            throw VertexShaderError
                .noBody(label)
        }
        let (type, decl) = try vertexOut(label: label)
        let vertexName = vertexNameFromLabel(label)
        return ("""
                \(decl)
                vertex \(type) \(vertexName)(){\(type) out;
                \(body)
                return out;
                }
                """, type)
    }
}

//Modifiers specific to VertexShader
public extension VertexShader{
    ///  Adds the declaration of the C-struct that used as output of the vertex shader
    /// - Parameter fields: Declaration of the output type.
    /// - Returns: Vertex shader with the added declaration of output type.
    func vertexOut(_ fields: String)->VertexShader{
        var v = self
        v.vertexOutFields = fields
        return v
    }
}
