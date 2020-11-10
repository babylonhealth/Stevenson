import Vapor
import Stevenson

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
    /// Handle incoming webhook for issue or PR comment
    /// - See also: [GitHub Docs](https://docs.github.com/en/free-pro-team@latest/developers/webhooks-and-events/webhook-events-and-payloads#issue_comment)
    func issueComment(
        on request: Request,
        ci: CircleCIService
    ) throws -> EventLoopFuture<Response> {
        try webhook(from: request)
            .flatMap { (action: CommentAction) -> EventLoopFuture<Response> in
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

                do {
                    return try self.pullRequest(
                        number: action.issue.number,
                        in: repo,
                        on: request
                    )
                    .flatMap { pullRequest -> EventLoopFuture<Response> in
                        let branch = pullRequest.head.ref

                        if textComponents[1] == "fastlane" {
                            do {
                                return try ci.runLane(
                                    textComponents: Array(textComponents.dropFirst(2)),
                                    branch: branch,
                                    project: repo.fullName,
                                    on: request
                                )
                                .flatMap { _ in HTTPResponseStatus.ok.encodeResponse(for: request) }
                            } catch {
                                return request.eventLoop.makeFailedFuture(error)
                            }
                        } else {
                            do {
                                return try ci.runPipeline(
                                    textComponents: Array(textComponents.dropFirst()),
                                    branch: branch,
                                    project: repo.fullName,
                                    on: request
                                )
                                .flatMap { _ in HTTPResponseStatus.ok.encodeResponse(for: request) }
                            } catch {
                                return request.eventLoop.makeFailedFuture(error)
                            }
                        }
                    }
                    .flatMapError { (error) -> EventLoopFuture<Response> in
                        do {
                            return try request.content.decode(PingAction.self)
                                .encodeResponse(for: request)
                                .map { _ in HTTPResponseStatus.ok }
                                .encodeResponse(for: request)
                        } catch {
                            return HTTPResponseStatus.badRequest.encodeResponse(for: request)
                        }
                    }
                } catch {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }
    }
}
