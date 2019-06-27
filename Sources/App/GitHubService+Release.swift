import Vapor
import Stevenson

extension GitHubService.Release {
    init(
        repo: GitHubService.Repository,
        branch: String
    ) throws {
        let branchComponents = branch.components(separatedBy: "/")
        // [CNSMR-1319] TODO: Use a config file to parametrise branch format

        guard branchComponents.count == 3 else {
            throw SlackService.Error.invalidParameter(
                key: SlackCommand.Option.branch.value,
                value: branch,
                expected: "(release|hotfix)/<app>/<version>"
            )
        }

        // in the form of "release/appName/1.2.3" or "hotfix/appName/1.2.3"
        let (releaseType, appName, version) = (branchComponents[0], branchComponents[1], branchComponents[2])

        guard ["release", "hotfix"].contains(releaseType) else {
            throw SlackService.Error.invalidParameter(key: "branch", value: branch, expected: "release or hotfix branch")
        }

        self.init(
            repository: repo,
            branch: branch,
            appName: appName,
            version: version
        )
    }

    var isSDK: Bool {
        return self.appName == "sdk"
    }
}
