import MetalKit
import SwiftUI
import OrderedCollections
import CoreMedia

/// The type for an object that contains uniforms values.
public final class UniformsContainer: ObservableObject{
    
    @Published var bufferAllocated = false
    
    var dict: OrderedDictionary<String, Property>
    public var mtlBuffer: MTLBuffer!{
        didSet{
            pointer = UnsafeRawPointer(mtlBuffer.contents())
        }
    }
    var device: MTLDevice!
    var pointer: UnsafeRawPointer?
    var metalDeclaration: MetalTypeDeclaration
    var metalType: String?
    var metalName: String?
    let length: Int
    let saveToDefaults: Bool
    let packed: Bool
    
    var pointerBinding: Binding<UnsafeRawPointer?>{
        Binding<UnsafeRawPointer?>(
            get: { self.pointer }, set: { _ in })
    }
    
    internal init(dict: OrderedDictionary<String, Property>,
                  mtlBuffer: MTLBuffer? = nil,
                  pointer: UnsafeRawPointer? = nil,
                  metalDeclaration: MetalTypeDeclaration,
                  metalType: String? = nil,
                  metalName: String? = nil,
                  length: Int,
                  saveToDefaults: Bool,
                  packed: Bool) {
        self.dict = dict
        self.mtlBuffer = mtlBuffer
        self.pointer = pointer
        self.metalDeclaration = metalDeclaration
        self.metalName = metalName
        self.length = length
        self.saveToDefaults = saveToDefaults
        self.packed = packed
    }
}
extension UniformsContainer: Equatable{
    public static func == (lhs: UniformsContainer, rhs: UniformsContainer) -> Bool {
        lhs === rhs
    }
}

//init and setup
public extension UniformsContainer{
    /// Creates a uniforms container
    /// - Parameters:
    ///   - descriptor: The descriptor that contains the properties of the uniforms.
    ///   - type: The type name for the Metal struct for uniforms.
    ///   - name: The name of the parameter by which the uniforms struct will be passed to your shaders.
    ///   - saveToDefaults: Indicates whether the uniforms should be saved in User Defaults system
    ///   persistently across launches of your app.
    convenience init(_ descriptor: UniformsDescriptor,
         type: String? = nil,
         name: String? = nil,
         saveToDefaults: Bool = true){
        print("UniformsContainer init:")
        var dict = descriptor.dict
        var offset = 0
        var uniformsStructMetalType: String
        if let type = type{
            uniformsStructMetalType = type
        }else{
            uniformsStructMetalType = "Uniforms"
        }
        var declaration = "struct " + uniformsStructMetalType
        declaration += "{\n"
        for t in descriptor.dict{
            let propertyMetalType = t.value.type.metalType(packed: descriptor.packed)
            var property = t.value
            property.offset = offset
            dict[t.key] = property
            offset += propertyMetalType.length
            declaration += "   "
            declaration += propertyMetalType.string + " " + t.key + ";\n"
            print(property)
        }
        declaration += "};\n"
        
        let metalDeclaration = MetalTypeDeclaration(typeName: uniformsStructMetalType,
                                                    declaration: declaration)

        self.init(dict: dict,
                  metalDeclaration: metalDeclaration,
                  metalName: name,
                  length: offset,
                  saveToDefaults: saveToDefaults,
                  packed: descriptor.packed)
    }
    
    /// Setups Uniforms Container before rendering
    /// - Parameter device: Metal device.
    public func setup(device: MTLDevice){
        print("Uniforms Container Setup")
        self.device = device
        if pointer == nil{
            var bytes = dict.values.flatMap{ $0.initValue }
            mtlBuffer = device.makeBuffer(bytes: &bytes, length: length)
            
            if saveToDefaults{
                print("load Defaults")
                loadFomDefaults()
                //defaultsLoaded = true
            }else{
                loadInitialValues()
            }
            DispatchQueue.main.async { [unowned self] in
                self.bufferAllocated = true
            }
        }
    }
    /// Loads Initial Values for Uniforms.
    func loadInitialValues(){
        print("Load Initial Values for Uniforms")
        _ = dict.map{ self.setArray($0.value.initValue, for: $0.key) }
    }
}

//Saving to and loading from User Defaults
public extension UniformsContainer{
    /// Loads uniforms values from User Defaults.
    ///
    /// If no value of an apropriate type is found for the key in User Defaults, the initial value is used.
    func loadFomDefaults(){
        print("Loading Uniforms values from User Defaults...")
        for p in dict.enumerated(){
            let key = userDefaultsKeyForUniformsKey(p.element.key)
            if let value = UserDefaults.standard.array(forKey: key){
                if let value = value as? [Float]{
                    print("Loaded: ",key , value)
                    setArray(value, for: p.element.key)
                    //values[p.offset] = value
                }else{
                    setArray(p.element.value.initValue, for: p.element.key)
                }
            }
        }
    }
    /// Saves a uniform value to User Defaults.
    /// - Parameters:
    ///   - value: An array containing the value to store.
    ///   It should be of the exact length, e.g. 1 for `Float`, 2 for `simd_float2`, ect.
    ///   - key: The name of a value in a uniforms contaner.
    func saveToDefaults(value: [Float], key: String){
        guard saveToDefaults
        else{ return }
        let key = userDefaultsKeyForUniformsKey(key)
        print("Saving to User Defaults: "+key, value)
        UserDefaults.standard.set(value, forKey: key)
    }
    
    /// Returns the key that is used to store and retrive the value from User Defaults.
    /// - Parameter name: Uniforms name.
    /// - Returns: key in User Defaults storage.
    func userDefaultsKeyForUniformsKey(_ name: String)->String{
        prefixForDefaults+name
    }
    /// Returns the name of a uniform value for the key that is used to store and retrive that value from User Defaults.
    /// - Parameter key: The key in User Defaults storage.
    /// - Returns: Uniforms value name.
    func uniformsKeyForUserDefaultsKey(_ key: String)->String?{
        if let range = key.range(of: prefixForDefaults){
            return String(key[range.upperBound...])
        }else{ return nil }
    }
    var prefixForDefaults: String{
        "Uniforms-"
    }
    ///Clears the User Defaults storage.
    ///
    ///Attention! All other stored values will also be erased!
    func clearDefaults(){
        print("Clearing Defaults for Uniforms")
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }
}
 
//Setters
public extension UniformsContainer{
    func setFloat(_ value: Float, for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: Float.self, capacity: 1).pointee = value
        saveToDefaults(value: [value], key: key)
    }
    func setFloat2(_ array: [Float], for key: String){
        setFloat2(simd_float2(array), for: key)
    }
    func setFloat2(_ value: simd_float2, for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_packed_float2.self, capacity: 1).pointee = value
        saveToDefaults(value: value.floatArray, key: key)
    }
    func setFloat3(_ array: [Float], for key: String){
        setFloat3(simd_float3(array), for: key)
    }
    func setFloat3(_ value: simd_float3, for key: String){
        guard let property = dict[key]
        else{ return }
        //!!! used custom simd_packed_float3 for the lack of inbuilt one!!!
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_packed_float3.self, capacity: 1).pointee = simd_packed_float3(value)
        saveToDefaults(value: value.floatArray, key: key)
    }
    func setFloat4(_ array: [Float], for key: String){
        setFloat4(simd_packed_float4(array), for: key)
    }
    func setFloat4(_ value: simd_float4, for key: String){
        guard let property = dict[key]
        else{ return }
        mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_packed_float4.self, capacity: 1).pointee = value
        saveToDefaults(value: value.floatArray, key: key)
    }
    func setSize(_ size: CGSize, for key: String){
        setFloat2([Float(size.width), Float(size.height)], for: key)
    }
    func setPoint(_ point: CGPoint, for key: String){
        setFloat2([Float(point.x), Float(point.y)], for: key)
    }
    func setRGBA(_ color: Color, for key: String){
        if let c = UIColor(color).cgColor.components{
            setFloat4(c.map{ Float($0) }, for: key)
        }
    }
    func setRGB(_ color: Color, for key: String){
        if let c = UIColor(color).cgColor.components?.dropLast(){
            setFloat3(c.map{ Float($0)}, for: key)
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
}
//Getters
public extension UniformsContainer{
    func getArray(_ key: String)->[Float]?{
        guard let property = dict[key]
        else{ return nil }
        
        let type = property.type

        switch type {
        case .float:
            let pointer = mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_float1.self, capacity: 1)
            return [pointer.pointee]
        case .float2:
            let pointer = mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_packed_float2.self, capacity: 1)
            return pointer.pointee.floatArray
        case .float3:
            let pointer = mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_packed_float3.self, capacity: 1)
            return pointer.pointee.floatArray
        case .float4:
            let pointer = mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: simd_packed_float2.self, capacity: 1)
            return pointer.pointee.floatArray
        }
//        let indices = property.initValue.indices
//        let pointer = mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: Float.self, capacity: indices.count)
//        return indices.map{ pointer[$0] }
    }
    func getFloat(_ key: String)->Float{
        guard let property = dict[key], mtlBuffer != nil
        else{ return 0 }
        return mtlBuffer.contents().advanced(by: property.offset).bindMemory(to: Float.self, capacity: 1).pointee
    }
}
//import and export Uniforms
public extension UniformsContainer{
    ///Returns uniforms encoded into json.
    var json: Data?{
        var dictToEncode: [String: Encodable] = [:]
        for p in dict{
            let type = p.value.type
            let pointer = self.pointer!.advanced(by: p.value.offset)
            let value: Encodable
            switch type{
            case .float: value = pointer.bindMemory(to: Float.self, capacity: 1).pointee
            case .float2: let v = pointer.bindMemory(to: simd_packed_float2.self, capacity: 1).pointee
                value = v.floatArray
            case .float3: let v = pointer.bindMemory(to: simd_packed_float3.self, capacity: 1).pointee
                value = v.floatArray
            case .float4: let v = pointer.bindMemory(to: simd_packed_float4.self, capacity: 1).pointee
                value = v.floatArray
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
    
    /// Import uniforms from json data.
    /// - Parameters:
    ///   - json: Json data.
    ///   - type: Metal type that will be useed to address uniforms in Metal library code.
    ///   - name: Name of variable by which uniforms will be accessible in Metal library code.
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
    func copyFrom(_ source: UniformsContainer){
        guard let sourceBufer = source.mtlBuffer
        else{ return }
        let length = sourceBufer.length
        let bytes = sourceBufer.contents()
        self.mtlBuffer = source.device.makeBuffer(bytes: bytes,
                                                  length: length)
        self.device = source.device
    }
}

extension SIMD{
    var floatArray: [Float]{
        self.indices.map{self[$0] as! Float}
    }
}

