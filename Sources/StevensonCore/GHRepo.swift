import Foundation
import Vapor

typealias Version = String

public struct GHRepo {
    public let key: String
    public let fullName: String
    public let baseBranch: String

    public init(key: String, fullName: String, baseBranch: String) {
        self.key = key
        self.fullName = fullName
        self.baseBranch = baseBranch
    }
}
