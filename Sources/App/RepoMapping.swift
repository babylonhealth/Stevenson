import Stevenson
import Vapor

struct RepoMapping {
    let repository: GitHubService.Repository
    let environment: JiraService.CRPIssueFields.Environment
    let jiraSummary: (GitHubService.Release) -> String
}

extension RepoMapping {
    // [CNSMR-1319] TODO: Use a config file to parametrise repo list
    static let all: [String: RepoMapping] = [
        "ios": RepoMapping(
            repository: GitHubService.Repository(fullName: Environment.get("GITHUB_REPO_IOS")!, baseBranch: "develop"),
            environment: .appStore,
            jiraSummary: {
                "Publish iOS \($0.appName ?? "Babylon") App v\($0.version) to the AppStore"
        }),
        "android": RepoMapping(
            repository: GitHubService.Repository(fullName: Environment.get("GITHUB_REPO_ANDROID")!, baseBranch: "master"),
            environment: .playStore,
            jiraSummary: {
                return "Publish Android \($0.appName ?? "Babylon") App v\($0.version) to the PlayStore"
        })
    ]
}
