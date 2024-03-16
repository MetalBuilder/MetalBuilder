import SwiftUI
import OrderedCollections

/// View that allows you to edit uniforms in real-time.
public struct UniformsView: View {
    
    /// Creates a uniforms view.
    /// - Parameter uniforms: The uniforms container.
    public init(_ uniforms: UniformsContainer, onChange: @escaping (String?)->()={_ in}){
        self.uniforms = uniforms
        self._onChange = onChange
    }
    
    let _onChange: (String?)->()
    func onChange(_ group: String?){
        if wasStartup{
            _onChange(group)
        }
    }
    
    @ObservedObject public var uniforms: UniformsContainer
    
    @State var values: [[Float]] = []
    
    @State var wasStartup = false
    
    public var body: some View {
        ScrollView{
            VStack{
                HStack{
                    Button {
                        clearDefaults()
                    } label: {
                        HStack{
                            Image(systemName: "xmark.bin.fill")
                            Text("Clear Defaults")
                        }
                    }
                }
                ForEach(values.indices, id:\.self){ id in
                    let value = values[id]
                    let (name, property) = uniforms.dict.elements[id]
                    if property.show{
                        switch property.type{
                        case .float: SingleSlider(label: name,
                                                  range: property.range ?? (0...1),
                                                  initialValue: value[0]){
                            uniforms.setFloat($0, for: name)
                            onChange(property.group)
                            //saveToDefaults(value: [$0], name: name)
                        }
                        default: MultiSlider(label: name,
                                             range: property.range ?? (0...1),
                                             initialValue: value) { value in
                                //saveToDefaults(value: value, name: name)
                                switch value.count{
                                case 2: uniforms.setFloat2(value, for: name)
                                case 3: uniforms.setFloat3(value, for: name)
                                case 4: uniforms.setFloat4(value, for: name)
                                default: break
                                }
                            onChange(property.group)
                            }
                        }
                    }
                }
            }
        }
        .onAppear{
            if uniforms.bufferAllocated{
               startup()
            }
        }
        .onChange(of: uniforms.bufferAllocated){ _ in
            startup()
        }
    }
}
//private methods
extension UniformsView{
    func startup(){
        loadValues()
    }
    func loadValues(){
        wasStartup = false
        print("Reading Uniforms by Uniforms View")
        values = uniforms.dict.keys.map{
            self.uniforms.getArray($0)!
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.05){
            wasStartup = true
        }
    }
    func clearDefaults(){
        wasStartup = false
        uniforms.loadInitialValues()
        values = []
        DispatchQueue.main.asyncAfter(deadline: .now()+0.05){
            loadValues()
        }
    }
}

struct MultiSlider: View {
    let label: String
    let range: ClosedRange<Float>
    let initialValue: [Float]
    let setter: ([Float])->()
    
    @State var value: [Float] = []
    
    var body: some View {
        VStack{
            HStack{
                Text(label)
                VStack{
                    Divider()
                }
            }
            ForEach(value.indices, id:\.self){ id in
                SingleSlider(label: "\(id)",
                             range: range,
                             initialValue: initialValue[id]){
                    value[id] = $0
                }
            }
        }
        .onAppear{
            value = initialValue
        }
        .onChange(of: value) {
            setter($0)
        }
    }
}

struct SingleSlider: View {
    let label: String
    let range: ClosedRange<Float>
    let initialValue: Float
    
    let setter: (Float)->()
    
    @State var precision = 1
    @State var digits = 2
    @State var value: Float = 0
    
    var body: some View {
        HStack{
            //let _ = print("refresh slider")
            Text(label+": "+String(format:"%\(digits).\(precision)f", value))
                .monospacedDigit()
                .onAppear{
                    let lg = log10(range.upperBound-range.lowerBound)
                    precision = min(4, Int(4.0/(2+lg)))
                    digits = Int(lg)+precision
                }
            Spacer()
            Slider(value: $value, in: range)
                .onChange(of: value){
                    setter($0)
                }
                .onAppear{
                    value = initialValue
                }
                .onChange(of: initialValue) { newValue in
                    print("new initial")
                    value = newValue
                }
        }
    }
}


