import Vapor
import Stevenson

struct PingAction: Content {
    let zen: String
}

struct CommentAction: Content {
    let action: String
    let comment: Comment
    let issue: Issue

    struct Comment: Content {
        let body: String
    }

    struct Issue: Content {
        let number: Int
    }

    struct PullRequest: Content {
        let url: URL
    }
}

extension GitHubService {
    func webhook<T: Decodable>(from request: Request) throws -> Future<T> {
        let headers = request.http.headers

        guard
            headers.firstValue(name: .userAgent)?.hasPrefix("GitHub-Hookshot/") == true,
            headers.firstValue(name: .init("X-GitHub-Event")) == "issue_comment"
        else {
            throw Abort(.badRequest)
        }

        return try request.content.decode(T.self)
    }
}

extension GitHubService {
    // Handle incoming webhook for issue comment
    func issueComment(
        on request: Request,
        ci: CircleCIService
    ) throws -> Future<Response> {
        return try webhook(from: request).flatMap { (action: CommentAction) in
            guard action.comment.body.hasPrefix("@ios-bot-babylon") else {
                throw Abort(.badRequest)
            }

            let repo = RepoMapping.ios.repository

            return try self.pullRequest(
                number: action.issue.number,
                in: repo,
                on: request
            ).flatMap { pullRequest in
                let branch = pullRequest.head.ref

                let textComponents = action.comment.body.split(separator: " ")
                guard textComponents.count >= 2 else {
                    throw Abort(.badRequest)
                }

                if textComponents[1] == "fastlane" {
                    return try ci.runLane(
                        textComponents: Array(textComponents.dropFirst(2)),
                        branch: branch,
                        project: repo.fullName,
                        on: request
                    ).flatMap { _ in try HTTPResponse(status: .ok).encode(for: request) }
                } else {
                    return try ci.runPipeline(
                        textComponents: Array(textComponents.dropFirst()),
                        branch: branch,
                        project: repo.fullName,
                        on: request
                    ).flatMap { _ in try HTTPResponse(status: .ok).encode(for: request) }
                }
            }
        }.catchFlatMap { error -> Future<Response> in
            try request.content.decode(PingAction.self)
                .map { _ in HTTPResponse(status: .ok) }
                .catchMap { _ in HTTPResponse(status: .badRequest) }
                .encode(for: request)
        }
    }
}
