import Foundation
import Vapor

extension SlackService {
    public enum Error: Swift.Error, Debuggable {
        case invalidToken
        case invalidChannel(String, allowed: Set<String>)
        case missingParameter(key: String)
        case invalidParameter(key: String, value: String, expected: String)

        public var identifier: String {
            return "SlackService.Error"
        }

        public var reason: String {
            switch self {
            case .invalidToken:
                return "Invalid token"
            case let .invalidChannel(channel, allowed):
                return """
                    Invalid channel `\(channel)`. Command should be invoked from one of these channels:
                    \(allowed.map { "* `\($0)`" }.joined(separator: "\n"))
                    """
            case let .missingParameter(key):
                return "Missing parameter for `\(key)`"
            case let .invalidParameter(key, value, expected):
                return "Invalid parameter `\(value)` for `\(key)`. Expected \(expected)."
            }
        }
    }
}

protocol FailableService: Service {
    associatedtype ServiceError: Error & Decodable & Debuggable
}

extension FailableService {
    public func request<T: Decodable>(
        _ sourceLocation: SourceLocation,
        _ makeRequest: () throws -> Future<Response>
    ) throws -> Future<T> {
        return try makeRequest()
            .flatMap { response in
                try response.content
                    .decode(T.self)
                    .catchFlatMap { _ in
                        try response.content
                            .decode(ServiceError.self)
                            .thenThrowing { throw $0 }
                }
            }
            .catchError(sourceLocation)
    }

    public func request(
        _ sourceLocation: SourceLocation,
        _ makeRequest: () throws -> Future<Response>
    ) throws -> Future<Void> {
        return try makeRequest()
            .flatMap { response in
                guard response.http.status == .noContent else {
                    return try response.content
                        .decode(ServiceError.self)
                        .thenThrowing { throw $0 }
                }
                return response.future(())
            }
            .catchError(sourceLocation)
    }
}

extension CircleCIService: FailableService {
    struct ServiceError: Swift.Error, Decodable, Debuggable {
        let message: String
        let identifier: String = "CircleCIService"

        var reason: String {
            return message
        }
    }
}

extension GitHubService: FailableService {
    struct ServiceError: Swift.Error, Decodable, Debuggable {
        let message: String
        let identifier: String = "GitHubService"

        var reason: String {
            return message
        }
    }
}

extension JiraService: FailableService {
    public struct ServiceError: Swift.Error, Decodable, Debuggable {
        // See https://developer.atlassian.com/cloud/jira/platform/rest/v3/#status-codes for schema
        public let errorMessages: [String]
        public let errors: [String: String]
        public let identifier: String = "JiraService"

        public var reason: String {
            let allErrors = errorMessages + errors.sorted(by: <).map { "\($0): \($1)" }
            if allErrors.count > 1 {
                return allErrors
                    .enumerated()
                    .map { "[\($0.offset+1)] \($0.element)" }
                    .joined(separator: " ")
            } else {
                return allErrors.first ?? "Unknown error"
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
extension SlackService.Error {
    public var errorDescription: String? {
        return reason
    }
}

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

extension SlackService.Response {
    public init(error: Error, visibility: Visibility = .user) {
        #if DEBUG
        self.init(String(describing: error), visibility: visibility)
        #else
        self.init(error.localizedDescription, visibility: visibility)
        #endif
    }
}
