import MetalKit
import SwiftUI

// MPSUnaryPass
class EncodeGroupPass: MetalPass{
    
    var libraryContainer: LibraryContainer?
    let passes: [MetalPass]
    let repeating: MetalBinding<Int>
    let active: MetalBinding<Bool>
    let once: Bool
    
    init(_ passes: [MetalPass], component: EncodeGroup){
        self.passes = passes
        self.repeating = component.repeating
        self.active = component.active
        self.once = component.once
    }
    func setup(renderInfo: GlobalRenderInfo) throws{
        for pass in passes {
            try pass.setup(renderInfo: renderInfo)
        }
    }
    func prerun(renderInfo: GlobalRenderInfo) throws{
        for pass in passes {
            try pass.prerun(renderInfo: renderInfo)
        }
    }
    func encode(passInfo: MetalPassInfo) throws {
  
        let repeating = repeating.wrappedValue * (active.wrappedValue ? 1:0)
        if once{ active.wrappedValue = false }
        for _ in 0..<repeating{
            for pass in passes {
                try pass.encode(passInfo: passInfo)
            }
        }
    }
}
