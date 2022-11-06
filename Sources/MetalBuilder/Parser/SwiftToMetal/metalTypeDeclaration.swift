
import MetalKit

/// Returns a C-struct declaration corresponding to the given Swift type.
public func metalTypeDeclaration<T>(from swiftType: T, name: String?) -> MetalTypeDeclaration?{
    guard let type = swiftType as? MetalStruct.Type
    else{ return nil }
    let mirror = Mirror(reflecting: type.init())
    var metalName: String
    if let name = name{
        metalName = name
    }else{
        metalName = String(describing: mirror.subjectType)
    }
    var s = "struct " + metalName + "{\n"
    for child in mirror.children {
        if let label = child.label{
            guard let metalType = metalType(for: Swift.type(of: child.value))
            else{
                print("invalid type: ", type)
                return nil
            }
            s += "   "
            s += metalType + " "
            s += String(describing: label) + ";\n"
        }
    }
    s += "};\n"
    return MetalTypeDeclaration(typeName: metalName, declaration: s)
}

/// A struct containing an information on the C-type declaration
public struct MetalTypeDeclaration{
    let typeName: String
    let declaration: String
}

/// Returns a string with the Metal type corresponding to the given Swift type.
public func metalType(for swiftType: Any.Type)->String?{
    
    switch swiftType {
    case is Bool.Type: return "bool"
        
    case is UInt32.Type: return "uint"
    case is SIMD2<UInt32>.Type: return "uint2"
    case is SIMD3<UInt32>.Type: return "uint3"
    case is SIMD4<UInt32>.Type: return "uint4"
        
    case is Int32.Type: return "int"
    case is SIMD2<Int32>.Type: return "int2"
    case is SIMD3<Int32>.Type: return "int3"
    case is SIMD4<Int32>.Type: return "int4"
        
    case is Float.Type: return "float"
    case is SIMD2<Float>.Type: return "float2"
    case is SIMD3<Float>.Type: return "float3"
    case is SIMD4<Float>.Type: return "float4"
        
    case is simd_float2x2.Type: return "float2x2"
    case is simd_float2x3.Type: return "float2x3"
    case is simd_float2x4.Type: return "float2x4"
        
    case is simd_float3x2.Type: return "float3x2"
    case is simd_float3x3.Type: return "float3x3"
    case is simd_float3x4.Type: return "float3x4"
        
    case is simd_float4x2.Type: return "float4x2"
    case is simd_float4x3.Type: return "float4x3"
    case is simd_float4x4.Type: return "float4x4"
        
    default:
        return nil
    }
}

//func reflectedTypeToMetalType(_ type: String)->String?{
//    var metalType = ""
//
//    if let type = simdTypeToMetal(type){
//        metalType = type
//    }else{
//        //if SIMD not found assumng that type is float!!
//        metalType += "float"
//    }
//    return metalType
//}

//func metalType(for swiftType: Type.Any)->String?{
//
//    if let metalType = simdTypeToMetal(swiftType){
//        return metalType
//    }
//    //if SIMD not found trying to get non-vector type
//    if let metalType = swiftTypesToMetalTypes[swiftType]{
//        return metalType
//    }
//    return nil
//}

//func simdTypeToMetal(_ simdType: String)->String?{
//    guard let simdRange = simdType.range(of: "SIMD")
//    else{ return nil }
//    let dimRange = simdType[simdRange.lowerBound...]
//    guard let dim = dimRange.rangeOfCharacter(from: ["2", "3", "4"])
//    else { return nil }
//    let postSIMDRange = simdType[dim.lowerBound...]
//
//    let rightBracket = postSIMDRange.rangeOfCharacter(from: [">"])!
//    let leftTypeIndex = simdType.index(simdRange.upperBound, offsetBy: 2)
//    let rightTypeIndex = simdType.index(rightBracket.lowerBound, offsetBy: -1)
//    let type = String(simdType[leftTypeIndex...rightTypeIndex])
//
//    let mType = swiftTypesToMetalTypes[type]
//
//    guard let mType = mType
//    else{ return nil }
//    return mType+simdType[dim]
//}

