
import Foundation

enum MetalBuilderParserError: Error{
    case noFunctionInSource(String, String)
    case syntaxError(String)
    case wrongType(String)
    case noCount(String)
}

extension MetalBuilderParserError: LocalizedError{
    public var errorDescription: String?{
        switch self{
        case .noFunctionInSource(let prefix, let name):
            return "No \(prefix) \(name) function in source!"
        case .syntaxError(let message):
            return message
        case .wrongType(let message):
            return message
        case .noCount(let message):
            return message
        }
    }
}
