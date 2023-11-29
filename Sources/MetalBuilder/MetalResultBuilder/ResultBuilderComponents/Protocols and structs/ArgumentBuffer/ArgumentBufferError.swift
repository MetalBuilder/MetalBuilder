enum ArgumentBufferError: Error{
    case argumentBufferNoArgumentWithName(String, String)//argumentBuffer, argument
    case argumentBufferResourceUncastable(String, String)//argumentBuffer, argument
    case twoArgumentBuffersWithSameNameAndDifferentDescriptors(String)//argumentBuffer
    case gridFitSetTwice(String)
    
    var localizedDescription: String{
        switch self {
        case .argumentBufferNoArgumentWithName(let buffer, let argument):
            "Argument buffer \(buffer) has no argument \(argument)!"
        case .argumentBufferResourceUncastable(let buffer, let argument):
            "Argument buffer \(buffer) error! The resource \(argument) is uncastable to a known resource type!"
        case .twoArgumentBuffersWithSameNameAndDifferentDescriptors(let buffer):
            "Two argument buffers of the same name '\(buffer)' but different descriptors!"
        case .gridFitSetTwice(let resource):
            "GridFit is set twice by argument '\(resource)'!"
    }
    }
}
