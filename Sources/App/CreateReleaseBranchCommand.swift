import Vapor
import Stevenson
import Foundation
import Utility

struct CreateReleaseBranchCommand: Vapor.Command {
    enum Option {
        static let repo = "repo"
        static let responseURL = "responseURL"
    }
    let arguments: [CommandArgument] = [
        .argument(name: Option.repo)
    ]
    let options: [CommandOption] = [
        CommandOption.value(name: Option.responseURL)
    ]
    let help: [String] = []

    func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        let github: GitHubService = try context.container.make()

        let repo: GitHubService.Repository = try attempt {
            try RepoMapping.all[context.argument(Option.repo)]?.repository
        }
        let responseURL = context.options[Option.responseURL]

        return try github.branch(
            in: repo,
            name: repo.baseBranch,
            on: context.container
            )
            .and(
                github.releases(in: repo, on: context.container).map { tags -> String in
                    let latestVersion: Version = try attempt {
                        let allVersions = tags.compactMap { (tag) -> Version? in
                            return matches(regex: repo.releaseTag, in: tag).first.flatMap(Version.init(string:))
                        }
                        return allVersions.sorted(by: >).first
                    }
                    let nextVersion = Version(latestVersion.major, latestVersion.minor + 1, 0)
                    return "release/\(nextVersion)"
                }
            )
            .flatMap { (head, branch) in
                try github.createBranch(
                    in: repo,
                    name: branch,
                    from: head,
                    on: context.container
                    )
                    .map { branch in "🚀 Release branch created `\(branch)`" }
                    .mapIfError { error in "⚠️ Failed to create branch `\(branch)`:\n`\(error.localizedDescription)`" }
            }
            .flatMap { response in
                guard let responseURL = responseURL else {
                    return .done(on: context.container)
                }

                return try context.container.client()
                    .post(responseURL) {
                        try $0.content.encode(SlackResponse(response))
                    }
                    .catchError(.capture())
                    .then { _ in .done(on: context.container) }
            }
    }
}

// Ref: https://stemmetje.com/regular-expression-capture-groups-in-swift-3-on-linux/
private func matches(regex: String, in text: String) -> [String] {
    do {
        let regex = try NSRegularExpression(pattern: regex)
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        return results.map { nsString.substring(with: $0.range) }
    } catch let error {
        print("invalid regex: \(error.localizedDescription)")
        return []
    }
}
