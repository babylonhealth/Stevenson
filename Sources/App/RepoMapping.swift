import Stevenson
import Vapor

struct RepoMapping {
    let repository: GitHubService.Repository
    let crp: CRP

    struct CRP {
        let environment: JiraService.CRPIssueFields.Environment
        let jiraSummary: (GitHubService.Release) -> String
    }
}

extension RepoMapping {
    // [CNSMR-1319] TODO: Use a config file to parametrise repo list
    static let ios = RepoMapping(
        repository: GitHubService.Repository(
            fullName: "Babylonpartners/babylon-ios",
            baseBranch: "develop"
        ),
        crp: CRP(
            environment: .appStore,
            jiraSummary: {
                if $0.isSDK {
                    return "Publish iOS SDK v\($0.version) to our partners"
                } else {
                    return "Publish iOS \($0.appName) App v\($0.version) to the AppStore"
                }
            }
        )
    )

    static let android = RepoMapping(
        repository: GitHubService.Repository(
            fullName: "Babylonpartners/babylon-android",
            baseBranch: "master"
        ),
        crp: CRP(
            environment: .playStore,
            jiraSummary: {
                if $0.isSDK {
                    return "Publish Android SDK v\($0.version) to our partners"
                } else {
                    return "Publish Android \($0.appName) App v\($0.version) to the PlayStore"
                }
            }
        )
    )

    static let all: [String: RepoMapping] = [
        "ios": ios,
        "android": android
    ]
}
