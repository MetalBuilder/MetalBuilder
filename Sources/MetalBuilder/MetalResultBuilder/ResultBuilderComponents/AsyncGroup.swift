import SwiftUI
import MetalKit

public func gpuStartCapture(){
    // capture
    let device = MTLCreateSystemDefaultDevice()

    let captureDescriptor = MTLCaptureDescriptor()
    captureDescriptor.captureObject = device
    // destination is developerTools by default

    try? MTLCaptureManager.shared().startCapture(with: captureDescriptor)
}
public func gpuStopCapture(){
    if MTLCaptureManager.shared().isCapturing {
           MTLCaptureManager.shared().stopCapture()
       }
}


public func not(_ arg: MetalBinding<Bool>) -> MetalBinding<Bool>{
    MetalBinding<Bool>.init {
        !arg.wrappedValue
    } set: {
        arg.wrappedValue = !$0
    }
}

public protocol AsyncParameters{
    static var nothing: Self { get }
    mutating func add(_ new: Self?)
}

public protocol AsyncGroupInfoProtocol: class{
    func startup(_ device: MTLDevice)
    var pass: AsyncGroupPass? { get set }
    var commandQueue: MTLCommandQueue? { get set }
}

public class AsyncGroupInfo<T: AsyncParameters>: AsyncGroupInfoProtocol{
    public init(label: String = "Async Queue",
                runOnStartup: Bool=false,
                rerun: Bool=true,
                completion: @escaping (T)->() = {_ in }){ //rerun if called when busy(e.g. to match probable changed value)
        self.label = label
        self.runOnStartup = runOnStartup
        self.rerunIfCalledWhenBusy = rerun
        self.completion = completion
        //self.whenBusy = whenBusy
        
        busy = MetalBinding<Bool>.init{
            self._busy
        } set: {
            self._busy = $0
        }
        complete = MetalBinding<Bool>.init{
            self._complete
        } set: {
            self._complete = $0
        }
        wasCompleteOnce = MetalBinding<Bool>.init{
            self._wasCompleteOnce
        } set: {
            self._wasCompleteOnce = $0
        }
    }
    
    public var busy: MetalBinding<Bool>!
    public var complete: MetalBinding<Bool>!
    public var wasCompleteOnce: MetalBinding<Bool>!
    
    public var completion: (T)->()
    
    public func setReady(){
        complete.wrappedValue = false
    }

    var _wasCompleteOnce = false
    var _complete: Bool = false{
        didSet{
            if _complete == false{
                _busy = false
            }else{
                _wasCompleteOnce = true
            }
        }
    }
    var _busy: Bool = true
    
    var runOnStartup: Bool
    var rerunIfCalledWhenBusy: Bool
    
    private let functionCheckQueue = DispatchQueue(label: "Metal Builder async group check queue",
                                                   attributes: .concurrent)
    private let functionQueue = DispatchQueue(label: "Metal Builder async group function queue",
                                              //qos: .background,
                                              attributes: .concurrent)
    var wasCalledWhenBusy: Bool = false
    
    //var renderInfo: GlobalRenderInfo!
    public var commandQueue: MTLCommandQueue?{
        didSet{
            commandQueue!.label = self.label
        }
    }
    var label: String
    var commandBuffer: MTLCommandBuffer!
    public var pass: AsyncGroupPass?
    
    var tempParameters = T.nothing
    public var parameters = T.nothing
    
    let completedGPUWorkSemaphore = DispatchSemaphore(value: 1)
    
    public func run(_ parameters: T?=nil, once: Bool=false) throws{
        functionCheckQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            guard !self.busy.wrappedValue
            else {
                print("running: busy")
                print("adding updates: ", parameters)
                self.tempParameters.add(parameters)
                //self.whenBusy(parameters)
                if !once {
                    self.wasCalledWhenBusy = true
                }
                return
            }
            
            self._busy = true
            print("accumulated tempParameters was: ", self.tempParameters)
            print("new parameters are: ", parameters)
            self.tempParameters.add(parameters)
            self.parameters = tempParameters
            tempParameters = .nothing
            
            try! self.dispatch(once: once)
        }
    }
    
    public func startup(_ device: MTLDevice){
        _busy = false
        if runOnStartup{
            try! dispatch(once: true)
        }
    }
    
    func dispatch(once: Bool) throws{
        functionQueue.sync{
            self.commandBuffer = try! self.startEncode()
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            
            let passInfo = MetalPassInfo(getCommandBuffer: self.getCommandBuffer,
                                         drawable: nil,
                                         depthStencilTexture: nil,
                                         renderPassDescriptor: renderPassDescriptor){
                try! self.restartEncode(commandBuffer: self.commandBuffer)
            }
            
            print("async work: waiting for result to copy")
            
            //gpuStartCapture()
            
            try! self.pass!.encode(passInfo: passInfo)
            
            self.endEncode(commandBuffer: self.commandBuffer)
            
            //gpuStopCapture()
            
            print("async work: ended encoding")
            
            completedGPUWorkSemaphore.wait()
            
            print("async work: ended GPU work")
            
            self.functionCheckQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                if self.rerunIfCalledWhenBusy && !once && self.wasCalledWhenBusy{
                    
                    self.wasCalledWhenBusy = false
                    
                    print("accumulated tempParameters was: ", self.tempParameters)
                    print("they will be used now!")
                    self.parameters = tempParameters
                    tempParameters = .nothing
                    
                    try! self.dispatch(once: false)
                }else{
                    self._complete = true
                    completion(self.parameters)
                }
            }
        }
    }
}
extension AsyncGroupInfo{
    func getCommandBuffer()->MTLCommandBuffer{
        self.commandBuffer
    }
    func startEncode() throws -> MTLCommandBuffer{
        
        guard let commandBuffer = commandQueue!.makeCommandBuffer()
        else{
            throw MetalBuilderRendererError
                .noCommandBuffer
        }
        return commandBuffer
    }
    func endEncode(commandBuffer: MTLCommandBuffer){
        
        commandBuffer.commit()

        commandBuffer.waitUntilCompleted()
        
        self.completedGPUWorkSemaphore.signal()
    }
    func restartEncode(commandBuffer: MTLCommandBuffer) throws{
        endEncode(commandBuffer: commandBuffer)
        self.commandBuffer = try startEncode()
    }
}

/// Encodes a group of components for async dispatch.
public struct AsyncGroup: MetalBuilderComponent{
    
    var info: AsyncGroupInfoProtocol
    //public let librarySource: String?
    @MetalResultBuilder public let metalContent: MetalContent
    
    /// Creates an async group component.
    /// - Parameters:
    ///   - info: reference to the object that contains data for controlling the group's dispatch.
    ///   - metalContent: The ResultBuilder closure containing MetalBuilder components.
    public init(info: AsyncGroupInfoProtocol,
                //librarySource: String? = nil,
                @MetalResultBuilder metalContent: ()->MetalContent) {
        self.info = info
        self.metalContent = metalContent()
    }
}
