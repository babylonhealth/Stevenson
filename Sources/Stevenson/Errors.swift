import Foundation
import Vapor

extension SlackService {
    public enum Error: Swift.Error, Debuggable {
        case invalidToken
        case invalidChannel
        case missingParameter(key: String)
        case invalidParameter(key: String, value: String, expected: String)

        public var identifier: String {
            return ""
        }

        public var reason: String {
            switch self {
            case .invalidToken:
                return "Invalid token"
            case .invalidChannel:
                return "Invalid channel"
            case .missingParameter(let key):
                return "Missing parameter for `\(key)`"
            case .invalidParameter(let key, let value, let expected):
                return "Invalid parameter `\(value)` for `\(key)`. Expected \(expected)."
            }
        }
    }
}

public struct NilValueError: Error, Debuggable {
    public let identifier = "nilValue"
    public let reason = "Unexpected nil value"
}

public struct ThrowError: Error, Debuggable {
    public let error: Error
    public let identifier: String
    public let reason: String
    public let sourceLocation: SourceLocation?

    init(error: Error, sourceLocation: SourceLocation) {
        self.error = error

        let _sourceLocation: SourceLocation?
        if let throwError = error as? ThrowError {
            self.identifier = throwError.identifier
            self.reason = throwError.reason
            _sourceLocation = throwError.sourceLocation
        } else if let debuggable = error as? Debuggable {
            self.identifier = "\(type(of: debuggable)).\(debuggable.identifier)"
            self.reason = debuggable.reason
            _sourceLocation = debuggable.sourceLocation
        } else {
            self.identifier = "\(type(of: error))"
            self.reason = error.localizedDescription
            _sourceLocation = sourceLocation
        }

        #if DEBUG
        self.sourceLocation = _sourceLocation ?? sourceLocation
        #else
        self.sourceLocation = nil
        #endif
    }

    init(error: Error, file: String, line: UInt, column: UInt, function: String) {
        self.init(
            error: error,
            sourceLocation: SourceLocation(
                file: file,
                function: function,
                line: line,
                column: column,
                range: nil
            )
        )
    }
}


#if !DEBUG
extension ThrowError: LocalizedError {
    public var errorDescription: String? {
        return reason
    }
}
#endif

public func attempt<T>(
    file: StaticString = #file,
    line: UInt = #line,
    column: UInt = #column,
    function: StaticString = #function,
    expr: () throws -> T?
) throws -> T {
    do {
        guard let value = try expr() else {
            throw NilValueError()
        }
        return value
    } catch {
        throw ThrowError(error: error, file: "\(file)", line: line, column: column, function: "\(function)")
    }
}

public func attempt<T>(
    file: StaticString = #file,
    line: UInt = #line,
    column: UInt = #column,
    function: StaticString = #function,
    expr: () throws -> T?
) throws -> T? {
    do {
        return try expr()
    } catch {
        throw ThrowError(error: error, file: "\(file)", line: line, column: column, function: "\(function)")
    }
}

extension Future {
    public func catchError(_ sourceLocation: SourceLocation) -> Future<Expectation> {
        return catchFlatMap { (error) -> EventLoopFuture<T> in
            throw ThrowError(error: error, sourceLocation: sourceLocation)
        }
    }
}
