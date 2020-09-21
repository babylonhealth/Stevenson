import Vapor
import Stevenson

struct PingAction: Content {
    let zen: String
}

struct CommentAction: Content {
    let action: String
    let comment: Comment
    let issue: Issue
    let repository: Repository

    struct Comment: Content {
        let body: String
    }

    struct Issue: Content {
        let number: Int
    }

    struct Repository: Content {
        let full_name: String
    }
}

extension GitHubService {
    func webhook<T: Decodable>(from request: Request) throws -> EventLoopFuture<T> {
        let headers = request.headers

        guard
            headers.first(name: .userAgent)?.hasPrefix("GitHub-Hookshot/") == true
        else {
            throw Abort(.badRequest)
        }

        let requestContent = try request.content.decode(T.self)
        return request.eventLoop.future(requestContent)
    }
}

extension GitHubService {
    // Handle incoming webhook for issue or PR comment
    // https://developer.github.com/v3/activity/events/types/#issuecommentevent
    func issueComment(
        on request: Request,
        ci: CircleCIService
    ) throws -> EventLoopFuture<Response> {
        try webhook(from: request)
            .flatMapThrowing { (action: CommentAction) -> EventLoopFuture<Response> in
            let headers = request.headers
            let textComponents = action.comment.body.split(separator: " ")

            guard
                headers.first(name: .init("X-GitHub-Event")) == "issue_comment",
                action.comment.body.hasPrefix("@ios-bot-babylon"),
                textComponents.count >= 2,
                let repo = RepoMapping.all.first(where: { _, mapping in
                    action.repository.full_name == mapping.repository.fullName
                })?.value.repository
            else {
                // return ok code so that we don't have hooks reported as failed on github
                return request.eventLoop.future(Response(status: .ok))
            }

            return try self.pullRequest(
                number: action.issue.number,
                in: repo,
                on: request
            ).flatMapThrowing { pullRequest in
                let branch = pullRequest.head.ref

                if textComponents[1] == "fastlane" {
                    return try ci.runLane(
                        textComponents: Array(textComponents.dropFirst(2)),
                        branch: branch,
                        project: repo.fullName,
                        on: request
                    ).flatMapThrowing { _ in try HTTPResponseStatus.ok.encode(for: request) }
                } else {
                    return try ci.runPipeline(
                        textComponents: Array(textComponents.dropFirst()),
                        branch: branch,
                        project: repo.fullName,
                        on: request
                    ).flatMapThrowing { _ in try HTTPResponseStatus.ok.encode(for: request) }
                }
            }
        }.catchFlatMap { error -> EventLoopFuture<Response> in
            try request.content.decode(PingAction.self)
                .map { _ in HTTPResponse(status: .ok) }
                .catchMap { _ in HTTPResponse(status: .badRequest) }
                .encode(for: request)
        }
    }
}
