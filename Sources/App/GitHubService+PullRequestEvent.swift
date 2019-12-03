import Vapor
import Stevenson

struct PingAction: Content {
    let zen: String
}

struct PullRequestEvent: Content {
    let action: String
    let number: Int
    let repository: Repository
    let label: Label

    struct Label: Content {
        let name: String
    }

    struct Repository: Content {
        let full_name: String
    }
}

extension GitHubService {
    // Handle incoming webhook for PR events
    // https://developer.github.com/v3/activity/events/types/#pullrequestevent
    func pullRequestEvent(
        on request: Request,
        ci: CircleCIService
    ) throws -> Future<Response> {
        return try webhook(from: request).flatMap { (action: PullRequestEvent) in
            let headers = request.http.headers

            guard
                headers.firstValue(name: .init("X-GitHub-Event")) == "pull_request",
                action.action == "labeled",
                let repo = RepoMapping.all.first(where: { _, mapping in
                    action.repository.full_name == mapping.repository.fullName
                })?.value.repository,
                action.label == "Merge" || action.label == "Run checks 🤖"
            else {
                // fail command but still return ok code so that we don't have hooks reported as failed on GitHub
                return request.future(request.response(http: .init(status: .ok)))
            }

            return try self.pullRequest(
                number: action.number,
                in: repo,
                on: request
            ).flatMap { pullRequest in
                let branch = pullRequest.head.ref

                return try ci.runPipeline(
                    textComponents: "test_pr",
                    branch: branch,
                    project: repo.fullName,
                    on: request
                ).flatMap { _ in try HTTPResponse(status: .ok).encode(for: request) }
            }
        }.catchFlatMap { error -> Future<Response> in
            try request.content.decode(PingAction.self)
                .map { _ in HTTPResponse(status: .ok) }
                .catchMap { _ in HTTPResponse(status: .badRequest) }
                .encode(for: request)
        }
    }
}
