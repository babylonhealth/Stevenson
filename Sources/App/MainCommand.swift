import Foundation
import Vapor
import Stevenson

extension SlackCommand {
    static let stevenson = { (ci: CircleCIService, jira: JiraService, github: GitHubService) in
        SlackCommand(
            name: "stevenson",
            help: """
            Invokes lane, beta or AppStore build or runs arbitrary workflow.

            Parameters:
            - name of the workflow or sub command to run
            - list of workflow or sub command parameters in the fastlane format (e.g. `param:value`)
            - `branch`: name of the branch to run the lane on. Default is `\(RepoMapping.ios.repository.baseBranch)`

            Example:
            `/stevenson ui_tests param:value \(Option.branch.value):develop`
            """,
            allowedChannels: [],
            subCommands: [
                .fastlane(ci),
                .testflight(ci),
                .hockeyapp(ci),
                .crp(jira, github)
            ],
            run: { metadata, container in
                try runPipeline(
                    metadata: metadata,
                    ci: ci,
                    on: container
                )
        })
    }
}
