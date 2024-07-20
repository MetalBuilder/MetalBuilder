import MetalKit
import SwiftUI

public protocol ReceiverOfArgumentsContainer{
    var argumentsContainer: ArgumentsContainer { get set }
    var gridFit: GridFit? { get set }
}

public extension ReceiverOfArgumentsContainer{
    func argBuffer(_ argBuffer: ArgumentBuffer,
                          name: String?=nil,
                          space: String="constant",
                          _ useResources: UseResources) -> Self{
        var c = self
        c.gridFit = c.argumentsContainer.argumentBufferToKernel(argBuffer, name: name,
                                                                space: space, useResources)
            ?? self.gridFit
        return c
    }
    /// Passes a buffer to the compute kernel.
    /// - Parameters:
    ///   - container: The buffer container.
    ///   - offset: The number of buffer elements to offset.
    ///   - index: Buffer index in kernel arguments.
    /// - Returns: The Compute component with the added buffer argument.
    ///
    /// This method adds a buffer to the compute function and doesn't change the Metal library code.
    /// Use it if you want to declare the kernel's argument manually.
    func buffer<T>(_ container: MTLBufferContainer<T>,
                          offset: MetalBinding<Int> = .constant(0),
                          index: Int)->Self{
        var c = self
        c.argumentsContainer.buffer(container, offset: offset, index: index)
        return c
    }
    /// Passes a buffer to the compute kernel.
    /// - Parameters:
    ///   - container: The buffer container.
    ///   - offset: The number of buffer elements to offset.
    ///   - argument: The buffer argument describing the declaration that should be added to the kernel.
    ///   - fitThreads: Indicates if the threads dispatched for the compute kernel should be calculated
    /// from the size of this buffer.
    /// - Returns: The Compute component with the added buffer argument.
    ///
    /// This method adds a buffer to the compute function and parses the Metal library code,
    /// automatically adding an argument declaration to the kernel function.
    /// Use this modifier if you do not want to declare the kernel's argument manually.
    func buffer<T>(_ container: MTLBufferContainer<T>,
                          offset: MetalBinding<Int> = .constant(0),
                          argument: MetalBufferArgument,
                          fitThreads: Bool=false,
                          gridScale: MBGridScale?=nil)->Self{
        var c = self
        c.argumentsContainer.buffer(container, offset: offset, argument: argument)
        if fitThreads || gridScale != nil{
            c.gridFit = .fitBuffer(container, argument.name, gridScale ?? (1,1,1))
        }
        return c
    }
    /// Passes a buffer to the compute kernel.
    /// - Parameters:
    ///   - container: The buffer container.
    ///   - offset: The number of buffer elements to offset.
    ///   - space: The address space for this buffer, default is "constant".
    ///   - type: The optional Metal type of the elements of this buffer.If nil, the buffer's own `type` will be used.
    ///   - name: The optional name of the property that will be passed to the shader to access this buffer.
    ///   If nil, the buffer's own `name` will be used.
    ///   - fitThreads: Indicates if the threads dispatched for the compute kernel should be calculated
    /// from the size of this buffer.
    /// - Returns: The Compute component with the added buffer argument.
    ///
    /// This method adds a buffer to the compute function and parses the Metal library code,
    /// automatically adding an argument declaration to the kernel function.
    /// Use this modifier if you do not want to declare the kernel's argument manually.
    func buffer<T>(_ container: MTLBufferContainer<T>,
                          offset: MetalBinding<Int> = .constant(0),
                          space: String="constant",
                          type: String?=nil, 
                          name: String?=nil,
                          fitThreads: Bool=false,
                          gridScale: MBGridScale?=nil) -> Self{
        
        let argument = try! MetalBufferArgument(container, space: space, type: type, name: name, index: nil)
        return self.buffer(container, offset: offset, 
                           argument: argument,
                           fitThreads: fitThreads, 
                           gridScale: gridScale)
    }
    func bytes<T>(_ binding: MetalBinding<T>,
                         index: Int)->Self{
        var c = self
        c.argumentsContainer.bytes(binding, index: index)
        return c
    }
    func bytes<T>(_ binding: MetalBinding<T>,
                         argument: MetalBytesArgument)->Self{
        var c = self
        c.argumentsContainer.bytes(binding, argument: argument)
        return c
    }
//    func bytes<T>(_ binding: MetalBinding<T>,
//                         argument: MetalBytesArgument)->Self{
//        var c = self
//        c.argumentsContainer.bytes(binding.binding, argument: argument)
//        return c
//    }
    /// Passes a value to the compute kernel of a Compute component.
    /// - Parameters:
    ///   - binding: MetalBinding value created with the`@MetalState` property wrapper.
    ///   - space: The address space for this value, default is "constant".
    ///   - type: The optional Metal type of the value.
    ///   If nil, the value's own `type` will be used that is defined in `@MetalState` declaration for this value.
    ///   - name: The optional name of the property that will be passed to the shader to access this buffer.
    ///   If nil, the value's own `name` will be used that is defined in `@MetalState` declaration for this value.
    /// - Returns: The Render component with the added buffer argument to the compute kernel.
    ///
    /// This method adds a value to the  compute kernel of a Compute component and parses the Metal library code,
    /// automatically adding an argument declaration to the  compute kernel.
    /// Use this modifier if you do not want to declare the function's argument manually.
    func bytes<T>(_ binding: MetalBinding<T>,
                         type: String?=nil,
                         name: String?=nil,
                         index: Int?=nil)->Self{
        let argument = MetalBytesArgument(binding: binding,
                                          space: "constant",
                                          type: type,
                                          name: name,
                                          index: index)
        return bytes(binding, argument: argument)
    }
    /// Passes a value to the compute kernel of a Compute component.
    /// - Parameters:
    ///   - binding: The SwiftUI's binding.
    ///   - type: The optional Metal type of the value.
    ///   If nil, the value's own `type` will be used that is defined in `@State` declaration for this value.
    ///   - name: The optional name of the property that will be passed to the shader to access this value.
    ///   If nil, the value's own `name` will be used that is defined in `@State` declaration for this value.
    /// - Returns: The Compute component with the added buffer argument to the compute kernel.
    ///
    /// This method adds a value to the compute kernel of a Compute component and parses the Metal library code,
    /// automatically adding an argument declaration to the compute kernel.
    /// Use this modifier if you do not want to declare the function's argument manually.
//    func bytes<T>(_ binding: Binding<T>,
//                         type: String?=nil,
//                         name: String,
//                         index: Int?=nil)->Self{
//        let metalBinding = MetalBinding(binding: binding, metalType: type, metalName: name)
//        let argument = MetalBytesArgument(binding: metalBinding,
//                                          space: "constant",
//                                          type: type,
//                                          name: name,
//                                          index: index)
//        return bytes(binding, argument: argument)
//    }
    func uniforms(_ uniforms: UniformsContainer,
                         name: String?=nil) -> Self{
        var c = self
        c.argumentsContainer.uniforms(uniforms, name: name)
        return c
    }
    /// Passes a texture to the compute kernel.
    /// - Parameters:
    ///   - container: The texture container.
    ///   - index: The texture index in the kernel arguments.
    /// - Returns: The Compute component with the added texture argument.
    ///
    /// This method adds a texture to the compute function and doesn't change Metal library code.
    /// Use it if you want to declare the kernel's argument manually.
    func texture(_ container: MTLTextureContainer,
                        index: Int)->Self{
        var c = self
        c.argumentsContainer.texture(container, index: index)
        return c
    }
    /// Passes a texture to the compute kernel.
    /// - Parameters:
    ///   - container: The texture container or nil to use drawable texture.
    ///   - argument: The texture argument describing the declaration that should be added to the kernel.
    ///   - fitThreads: Indicates if the threads dispatched for the compute kernel should be calculated
    /// from the size of this texture.
    /// - Returns: The Compute component with the added texture argument.
    ///
    /// This method adds a texture to the compute function and parses the Metal library code,
    /// automatically adding an argument declaration to the kernel function.
    /// Use this modifier if you do not want to declare the kernel's argument manually.
    func texture(_ container: MTLTextureContainer,
                        argument: MetalTextureArgument,
                        fitThreads: Bool=false,
                        gridScale: MBGridScale?=nil)->Self{
        var c = self
        c.argumentsContainer.texture(container, argument: argument)
        if fitThreads || gridScale != nil{
            c.gridFit = .fitTexture(container, argument.name, gridScale ?? (1,1,1))
        }
        return c
    }
}
