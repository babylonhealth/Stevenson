import Foundation
import StevensonCore
import Vapor

enum RepoID: String, CaseIterable {
    case ios
    case android

    static func find(matching value: String) -> RepoID? {
        return RepoID.allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
    }

    var environment: JiraService.CRPIssueFields.Environment {
        switch self {
        case .ios: return .appStore
        case .android: return .playStore
        }
    }

    func jiraSummary(release: GitHubService.Release) -> String {
        switch self {
        case .ios:
            return "Publish iOS \(release.appName ?? "Babylon") App v\(release.version) to the AppStore"
        case .android:
            return "Publish Android \(release.appName ?? "Babylon") App v\(release.version) to the PlayStore"
        }
    }

    var repository: GitHubService.Repository {
        switch self {
        case .ios:
            return .init(
                fullName: Environment.get("GITHUB_REPO")!,
                baseBranch: "develop"
            )
        case .android:
            return .init(
                fullName: Environment.get("GITHUB_REPO_ANDROID")!,
                baseBranch: "master"
            )
        }
    }
}
