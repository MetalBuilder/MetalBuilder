import SwiftUI
import MetalKit

@resultBuilder
public enum MetalResultBuilder{
    public static func buildBlock(_ components: MetalContent...) -> MetalContent{
        components.flatMap{$0}
    }
    
    public static func buildEither(first component: MetalContent) -> MetalContent {
           component
       }
       
    public static func buildEither(second component: MetalContent) -> MetalContent {
       component
    }

    public static func buildOptional(_ component: MetalContent?) -> MetalContent {
        component ?? []
    }
    
    public static func buildExpression(_ expression: MetalBuilderComponent) -> MetalContent {
            [expression]
    }
        
//    public static func buildExpression(_ expression: MetalContent) -> MetalBuilderComponent {
//        expression
//    }
}

public typealias MetalContent = [MetalBuilderComponent]

public typealias MetalBuilderContent = (MetalBuilderRenderingContext) -> MetalContent
