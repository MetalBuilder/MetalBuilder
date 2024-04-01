
import MetalKit
import SwiftUI

public typealias AdditionalEncodeClosureForCompute = (MTLComputeCommandEncoder)->()
public typealias AdditionalPiplineSetupClosureForCompute = (MTLComputePipelineState, MTLLibrary)->()
public typealias PiplineSetupClosureForCompute = (MTLDevice, MTLLibrary)->(MTLComputePipelineState)

/// The component for dispatching compute kernels.
public struct Compute: MetalBuilderComponent, ReceiverOfArgumentsContainer{
    
    var kernel: String
    
    var stringArguments: [String] = []
    
    var drawableTextureIndex: Int?
    var indexType: IndexType = .uint
    var threadsPerThreadgroup: MetalBinding<MTLSize>?
    
    public var gridFit: GridFit?
    public var argumentsContainer = ArgumentsContainer(stages: nil)
    
    var librarySource: String = ""
    var bodySource: String = ""
    var argumentBuffersDeclarations: String = ""
    
    var additionalEncodeClosure: MetalBinding<AdditionalEncodeClosureForCompute>?
    var additionalPiplineSetupClosure: MetalBinding<AdditionalPiplineSetupClosureForCompute>?
    var piplineSetupClosure: MetalBinding<PiplineSetupClosureForCompute>?
    
    public init(_ kernel: String, source: String = ""){
        self.kernel = kernel
    }
    
    mutating func setup(supportFamily4: Bool) throws -> (ArgumentsData, String){
        try setupGrid()
        let source = try addComputeKernelArguments(addGridCheck: !supportFamily4)
        let argData = try self.argumentsContainer
            .getData(metalFunction: .compute(kernel))
        return (argData, source)
    }
    func addComputeKernelArguments(addGridCheck: Bool) throws -> String{
        guard bodySource != ""
        else { return librarySource }
        
        var bodySource = bodySource
        
        if addGridCheck{
            let gridCheck = try gridFit!.gridCheck
            bodySource = gridCheck + bodySource
        }
        
        let arg = try gridFit!
            .computeKernelArguments(bodyCode: bodySource,
                                    indexType: indexType, 
                                    gidCountBufferIndex: argumentsContainer.buffersAndBytesContainer.indexCounter)
        var strArgs = stringArguments.joined(separator: ", ")
        if strArgs != ""{
            strArgs = ", " + strArgs
        }
        let kernelDecl = "kernel void \(kernel) (\(arg)\(strArgs)){"
        return librarySource + kernelDecl + bodySource + "}"
    }
    mutating func setupGrid() throws{
        if gridFit == nil{
            throw MetalBuilderComputeError
            .noGridFit("No information for threads dispatching was set for the kernel: " +
                       kernel +
                       "\nUse 'grid' modifier or set index for drawable!")
        }
    }
}

// chaining functions for result builder
public extension Compute{
    /// Passes a drawable texture to the compute kernel.
    /// - Parameters:
    ///   - index: The texture index in the kernel arguments.
    /// - Returns: The Compute component with the added drawable texture argument.
    ///
    /// This method adds a drawable texture to the compute function and doesn't change Metal library code.
    /// Use it if you want to declare the kernel's argument manually.
//    func drawableTexture(index: Int, gridScale: MBGridScale?=nil)->Compute{
//        var c = self
//        c.drawableTextureIndex = index
//        c.gridFit = .drawable(gridScale ?? (1,1,1))
//        return c
//    }
    /// Passes a drawable texture to the compute kernel.
    /// - Parameters:
    ///   - argument: The texture argument describing the declaration that should be added to the kernel.
    ///   - fitThreads: Indicates whether the threads for the kernel should be dispatched to fit the drawable texture.
    ///
    /// This method adds a drawable texture to the compute function and parses the Metal library code,
    /// automatically adding an argument declaration to the kernel function.
    /// Use this modifier if you do not want to declare the kernel's argument manually.
    func drawableTexture(argument: MetalTextureArgument,
                         fitThreads: Bool = true,
                         gridScale: MBGridScale?=nil)->Compute{
        var c = self
        c.drawableTextureIndex = c.argumentsContainer.drawable(argument: argument)
        if fitThreads || gridScale != nil{
            c.gridFit = .drawable(argument.name, gridScale ?? (1,1,1))
        }
        return c
    }
    func grid(size: MetalBinding<Int>)->Compute{
        var c = self
        c.gridFit = .size1D(size)
        return c
    }
    func grid(size: Int)->Compute{
        var c = self
        c.gridFit = .size1D(MetalBinding<Int>.constant(size))
        return c
    }
    func grid(size2D: MetalBinding<(Int, Int)>)->Compute{
        var c = self
        c.gridFit = .size2D(size2D)
        return c
    }
    func grid(size3D: MetalBinding<MTLSize>)->Compute{
        var c = self
        c.gridFit = .size3D(size3D)
        return c
    }
//    func grid(fitTexture: MTLTextureContainer, gridScale: MBGridScale?=nil)->Compute{
//        var c = self
//        c.gridFit = .fitTexture(fitTexture, gridScale ?? (1,1,1))
//        return c
//    }
//    func gridFitDrawable(gridScale: MBGridScale?=nil)->Compute{
//        var c = self
//        c.gridFit = .drawable(gridScale ?? (1,1,1))
//        return c
//    }
//    func threadsFromBuffer(_ index: Int)->Compute{
//        var c = self
//        c.gridFit = .buffer(index)
//        return c
//    }
    func body(_ metalCode: String)->Compute{
        var c = self
        c.bodySource = metalCode
        return c
    }
    func source(_ metalCode: String)->Compute{
        var c = self
        c.librarySource = metalCode
        return c
    }
    /// Modifier for setting a closure for pipeline setup for Compute component.
    /// - Parameter closureBinding: MetalBinding to a closure for pipeline setup logic.
    /// - Returns: Compute component with a custom pipeline setup logic.
    ///
    /// Use this modifier if you want to create MTLComputePipelineState manually.
    func pipelineSetup(_ closureBinding: MetalBinding<PiplineSetupClosureForCompute>)->Compute{
        var c = self
        c.piplineSetupClosure = closureBinding
        return c
    }
    /// Modifier for setting a closure for pipeline setup for Compute component.
    /// - Parameter closure: closure for pipeline setup logic.
    /// - Returns: Compute component with a custom pipeline setup logic.
    ///
    /// Use this modifier if you want to create MTLComputePipelineState manually.
    func pipelineSetup(_ closure: @escaping PiplineSetupClosureForCompute)->Compute{
        self.pipelineSetup( MetalBinding<PiplineSetupClosureForCompute>.constant(closure))
    }
    /// Modifier for setting a closure for additional pipeline setup for Compute component.
    /// - Parameter closureBinding: MetalBinding to a closure for additional pipeline setup logic.
    /// - Returns: Compute component with the added additional pipeline setup logic.
    ///
    /// The closure provided in this modifier will run after all the internal pipeline setup logic is performed.
    func additionalPipelineSetup(_ closureBinding: MetalBinding<AdditionalPiplineSetupClosureForCompute>)->Compute{
        var c = self
        c.additionalPiplineSetupClosure = closureBinding
        return c
    }
    /// Modifier for setting a closure for additional pipeline setup for Compute component.
    /// - Parameter closure: closure for additional pipeline setup logic.
    /// - Returns: Compute component with the added additional pipeline setup logic.
    ///
    /// The closure provided in this modifier will run after all the internal pipeline setup logic is performed.
    func additionalPipelineSetup(_ closure: @escaping AdditionalPiplineSetupClosureForCompute)->Compute{
        self.additionalPipelineSetup( MetalBinding<AdditionalPiplineSetupClosureForCompute>.constant(closure))
    }
    /// Modifier for setting additional encode closure for Compute component.
    /// - Parameter closureBinding: MetalBinding to a closure for additional encode logic.
    /// - Returns: Compute component with the added additional encode logic.
    ///
    /// The closure provided in this modifier will run after all the internal encoding is performed
    /// right before the dispatch or before encoding of the next component.
    func additionalEncode(_ closureBinding: MetalBinding<AdditionalEncodeClosureForCompute>)->Compute{
        var c = self
        c.additionalEncodeClosure = closureBinding
        return c
    }
    /// Modifier for setting additional encode closure for Compute component.
    /// - Parameter closure: Closure for additional encode logic.
    /// - Returns: Compute component with the added additional encode logic.
    ///
    /// The closure provided in this modifier will run after all the internal encoding is performed
    /// right before the dispatch or before encoding of the next component.
    func additionalEncode(_ closure: @escaping AdditionalEncodeClosureForCompute)->Compute{
        self.additionalEncode(MetalBinding<AdditionalEncodeClosureForCompute>.constant(closure))
    }
    func threadsPerThreadgroup(_ sizeBinding: MetalBinding<MTLSize>)->Compute{
        var c = self
        c.threadsPerThreadgroup = sizeBinding
        return c
    }
    func threadsPerThreadgroup(_ size: MTLSize)->Compute{
        self.threadsPerThreadgroup(MetalBinding<MTLSize>.constant(size))
    }
    func gidIndexType(_ type: IndexType) -> Compute{
        var c = self
        c.indexType = type
        return c
    }
    func argument(_ string: String)->Compute{
        var c = self
        c.stringArguments.append(string)
        return c
    }
}
