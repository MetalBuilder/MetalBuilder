import MetalKit
import SwiftUI
import OrderedCollections

public final class UniformsContainer: ObservableObject{
    
    @Published var bufferAllocated = false
    
    var dict: OrderedDictionary<String, Property>
    var mtlBuffer: MTLBuffer!
    var pointer: UnsafeRawPointer?
    var metalDeclaration: String
    var metalName: String?
    let length: Int = 0
    let saveToDefaults: Bool
    
    internal init(dict: OrderedDictionary<String, Property>,
                  mtlBuffer: MTLBuffer? = nil,
                  pointer: UnsafeRawPointer? = nil,
                  metalDeclaration: String = "",
                  metalName: String? = nil,
                  saveToDefaults: Bool) {
        self.dict = dict
        self.mtlBuffer = mtlBuffer
        self.pointer = pointer
        self.metalDeclaration = metalDeclaration
        self.metalName = metalName
        self.saveToDefaults = saveToDefaults
    }
}
//init and setup
public extension UniformsContainer{
    convenience init(_ u: UniformsDescriptor,
         type: String? = nil,
         name: String? = nil,
         saveToDefaults: Bool = true){
        var dict = u.dict
        var offset = 0
        var metalDeclaration = "struct " + (type ?? "Uniforms")
        metalDeclaration += "{\n"
        for t in u.dict{
            let metalType = uniformsTypesToMetalTypes[t.value.type]!
            var property = t.value
            property.offset = offset
            dict[t.key] = property
            offset += metalType.length
            metalDeclaration += "   "
            metalDeclaration += t.key + " " + metalType.string + ";\n"
        }
        metalDeclaration += "};\n"

        self.init(dict: dict,
                  metalDeclaration: metalDeclaration,
                  metalName: name,
                  saveToDefaults: saveToDefaults)
    }
    
    /// Setups Uniforms Container before rendering
    /// - Parameter device: MTLDevice
    func setup(device: MTLDevice){
        var bytes = dict.values.flatMap{ $0.initValue }
        mtlBuffer = device.makeBuffer(bytes: &bytes, length: length)
        bufferAllocated = true
    }
}
 
//Modify and get state of properties with this functions
public extension UniformsContainer{
    func setFloat(_ value: Float, for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: Float.self, capacity: 1).pointee = value
    }
    func setFloat2(_ array: [Float], for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_float2.self, capacity: 1).pointee = simd_float2(array)
    }
    func setFloat3(_ array: [Float], for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_float3.self, capacity: 1).pointee = simd_float3(array)
    }
    func setFloat4(_ array: [Float], for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_float4.self, capacity: 1).pointee = simd_float4(array)
    }
    func setSize(_ size: CGSize, for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_float2.self, capacity: 1).pointee = [Float(size.width), Float(size.height)]
    }
    func setPoint(_ point: CGPoint, for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_float2.self, capacity: 1).pointee = [Float(point.x), Float(point.y)]
    }
    func setRGBA(_ color: Color, for key: String){
        guard let property = dict[key]
        else{ return }
        if let c = UIColor(color).cgColor.components{
            mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_float4.self, capacity: 1).pointee = simd_float4(c.map{ Float($0) })
        }
    }
    func setRGB(_ color: Color, for key: String){
        guard let property = dict[key]
        else{ return }
        if let c = UIColor(color).cgColor.components{
            mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_float3.self, capacity: 1).pointee = simd_float3(c.map{ Float($0) }.dropLast())
        }
    }
    func setArray(_ value: [Float], for key: String){
        if let property = dict[key]{
            switch property.type{
            case .float:
                setFloat(value[0], for: key)
            case .float2:
                if value.count == 2{
                    setFloat2(value, for: key)
                }
            case .float3:
                if value.count == 3{
                    setFloat3(value, for: key)
                }
            case .float4:
                if value.count == 4{
                    setFloat4(value, for: key)
                }
            }
        }
    }
    func getFloat(_ key: String)->Float?{
        guard let property = dict[key]
        else{ return nil }
        return mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: Float.self, capacity: 1).pointee
    }
}
//import and export Uniforms
extension UniformsContainer{
    ///Returns uniforms encoded into json
    var json: Data?{
        var dictToEncode: [String: Encodable] = [:]
        for p in dict{
            let type = p.value.type
            let pointer = mtlBuffer.contents().advanced(by: p.value.offset)
            let value: Encodable
            switch type{
            case .float: value = pointer.bindMemory(to: Float.self, capacity: 1).pointee
            case .float2: let v = pointer.bindMemory(to: simd_float2.self, capacity: 1).pointee
                value = v.indices.map({v[$0]})
            case .float3: let v = pointer.bindMemory(to: simd_float3.self, capacity: 1).pointee
                value = v.indices.map({v[$0]})
            case .float4: let v = pointer.bindMemory(to: simd_float4.self, capacity: 1).pointee
                value = v.indices.map({v[$0]})
            }
            dictToEncode[p.key] = value
        }
        do{
            return try JSONSerialization.data(withJSONObject: dictToEncode, options: .prettyPrinted)
        }catch{
            print(error)
            return nil
        }
    }
    
    /// Import uniforms from json data
    /// - Parameters:
    ///   - json: json data
    ///   - type: Metal type that will be useed to address uniforms in Metal library code
    ///   - name: Name of variable by which uniforms will be accessible in Metal library code
    func `import`(json: Data, type: String? = nil, name: String? = nil){
        guard let object = try? JSONSerialization.jsonObject(with: json)
        else { return }
        guard let dict = object as? [String:Any]
        else {
            print("bad json")
            return
        }
        var selfDict = self.dict
        for d in dict{
            if var property = selfDict[d.key]{
                switch property.type{
                case .float:
                    if let value = d.value as? Float{
                        setFloat(value, for: d.key)
                        property.initValue = [value]
                    }
                case .float2:
                    if let value = d.value as? [Float]{
                        setFloat2(value, for: d.key)
                        property.initValue = value
                    }
                case .float3:
                    if let value = d.value as? [Float]{
                        setFloat3(value, for: d.key)
                        property.initValue = value
                    }
                case .float4:
                    if let value = d.value as? [Float]{
                        setFloat4(value, for: d.key)
                        property.initValue = value
                    }
                }
                selfDict[d.key] = property
            }
        }
        self.dict = selfDict
    }
}

