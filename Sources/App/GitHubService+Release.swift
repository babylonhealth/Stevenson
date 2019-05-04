import Vapor
import Stevenson

extension GitHubService.Release {
    init(
        repo: GitHubService.Repository,
        branch: String
    ) throws {
        let branchComponents = branch.components(separatedBy: "/")
        // [CNSMR-1319] TODO: Use a config file to parametrise branch format
        guard branchComponents.count > 1, ["release", "hotfix"].contains(branchComponents[0]) else {
            throw SlackService.Error.invalidParameter(key: "branch", value: branch, expected: "release or hotfix branch")
        }
        let (appName, version): (String?, String)
        if branchComponents.count == 2 {
            // in the form of "release/1.2.3" or "hotfix/1.2.3"
            appName = nil
            version = branchComponents[1]
        } else if branchComponents.count == 3 {
            // in the form of "release/appName/1.2.3" or "hotfix/appName/1.2.3"
            appName = branchComponents[1]
            version = branchComponents[2]
        } else {
            throw SlackService.Error.invalidParameter(
                key: SlackCommand.Option.branch.value,
                value: branch,
                expected: "(release|hotfix)/<app>/<version>"
            )
        }

        self.init(
            repository: repo,
            branch: branch,
            appName: appName,
            version: version
        )
    }
}
