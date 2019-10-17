import Stevenson
import Vapor

struct RepoMapping {
    let repository: GitHubService.Repository
    let crp: CRP

    struct CRP {
        let environment: JiraService.CRPIssueFields.Environment
        let jiraVersionName: (GitHubService.Release) -> String
        let jiraSummary: (GitHubService.Release) -> String
    }
}

extension RepoMapping {
    // [CNSMR-1319] TODO: Use a config file to parametrise repo list
    static let ios = RepoMapping(
        repository: GitHubService.Repository(
            fullName: "babylonhealth/babylon-ios",
            baseBranch: "develop"
        ),
        crp: CRP(
            environment: .appStore,
            jiraVersionName: {
                let appName = $0.isSDK ? $0.appName.uppercased() : $0.appName
                return "iOS \(appName) \($0.version)"
            },
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
            fullName: "babylonhealth/babylon-android",
            baseBranch: "master"
        ),
        crp: CRP(
            environment: .playStore,
            jiraVersionName: {
                let appName = $0.isSDK ? $0.appName.uppercased() : $0.appName
                return "Android \(appName) \($0.version)"
            },
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
