import Foundation
import Vapor

extension SlackService {
    public enum Error: Swift.Error, Debuggable {
        case invalidToken
        case invalidChannel

        public var identifier: String {
            return ""
        }

        public var reason: String {
            switch self {
            case .invalidToken:
                return "Invalid token"
            case .invalidChannel:
                return "Invalid channel"
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
    public let stackTrace = Thread.callStackSymbols

    init(error: Error, sourceLocation: SourceLocation) {
        self.error = error

        if let throwError = error as? ThrowError {
            self.identifier = throwError.identifier
            self.reason = throwError.reason
            self.sourceLocation = throwError.sourceLocation ?? sourceLocation
        } else if let debuggable = error as? Debuggable {
            self.identifier = "\(type(of: debuggable)).\(debuggable.identifier)"
            self.reason = debuggable.reason
            self.sourceLocation = debuggable.sourceLocation ?? sourceLocation
        } else {
            self.identifier = "\(type(of: error))"
            self.reason = "\(error)"
            self.sourceLocation = sourceLocation
        }
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

extension Future {
    public func attemptMap<T>(to type: T.Type = T.self, _ callback: @escaping (Expectation) throws -> T) -> Future<T> {
        return map { value in
            try attempt {
                try callback(value)
            }
        }
    }

    public func catchError(_ sourceLocation: SourceLocation) -> Future<Expectation> {
        return catchFlatMap { (error) -> (EventLoopFuture<T>) in
            throw ThrowError(error: error, sourceLocation: sourceLocation)
        }
    }
}
