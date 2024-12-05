import SwiftUI

/// Protocol for declaring autonomous building blocks
///
/// if compileOptions are not nil the source will compile into separate library (still has issues)
/// otherwise the contents of `librarySource` will be concatinated to global LibrarySource.
/// - Important: If two or more BuildingBlocks have identical `librarySource` this source will be added only once.
public protocol MetalBuildingBlock: MetalBuilderComponent{
    var context: MetalBuilderRenderingContext { get }
    var helpers: String { get }
    var librarySource: String { get }
    var compileOptions: MetalBuilderCompileOptions? { get }
    @MetalResultBuilder var metalContent: MetalContent{ get }
    func setup()
    func startup(device: MTLDevice)
}

public extension MetalBuildingBlock{
    func setup(){
    }
    func startup(device: MTLDevice){
    }
    
    var helpers: String { "" }
    var librarySource: String { "" }
    var compileOptions: MetalBuilderCompileOptions? { nil }
}

