import StevensonCore
import Vapor

extension GHRepo {
    static let ios = GHRepo(
        key: "ios",
        fullName: Environment.get("GITHUB_REPO")!,
        baseBranch: "develop"
    )

    static let android = GHRepo(
        key: "android",
        fullName: Environment.get("GITHUB_REPO_ANDROID")!,
        baseBranch: "master"
    )

    static let allRepos: [GHRepo] = [.ios, .android]
    static func find(matching name: String) -> GHRepo? {
        return GHRepo.allRepos.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }
    }
}
