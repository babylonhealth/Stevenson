import Vapor
import Stevenson

extension GitHubService {
    enum Constants {
        static let jiraProjectPrefixPattern = jiraProjects
            .map(\.prefix)
            .joined(separator: "|")
        static let jiraProjects: [JiraService.Project] = [
            .core,
            .v3,
            .nhs,
            .consultations,
            .prescriptions,
            .avalon,
            .consumer,
            .sdk,
            .triage,
            .monitor,
            .testKits,
            .platform,
            .coreUS,
            .realTimeMatching,
            .appointments1,
            .paymentsEligibility,
            .partnership,
        ]
    }
}

extension GitHubService {
    /// Handle incoming webhook for pull request event
    /// - See also:
    ///   [GitHub Docs](https://docs.github.com/en/free-pro-team@latest/developers/webhooks-and-events/webhook-events-and-payloads#pull_request)
    func pullRequestEvent(
        on request: Request,
        jira: JiraService
    ) throws -> EventLoopFuture<Response> {
        try webhook(from: request)
            .flatMap { (pullRequest: PullRequest) -> EventLoopFuture<Response> in
                let headers = request.headers

                #warning("TODO check for PR `action` to be `merged`")
                guard headers.first(name: .init("X-GitHub-Event")) == "pull_request",
                    RepoMapping.all.first(where: { _, mapping in
                        pullRequest.repoFullname == mapping.repository.fullName
                    })?.value.repository != nil
                else {
                    // return ok code so that we don't have hooks reported as failed on github
                    return request.eventLoop.future(Response(status: .ok))
                }

                do {
                    // Update Jira tickets for PR
                    try self.updateTickets(
                        pullRequest: pullRequest,
                        jira: jira
                    )
                    return request.eventLoop.future(Response(status: .ok))
                } catch {
                    return request.eventLoop.makeFailedFuture(error)
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
    }
}

extension GitHubService {
    private func updateTickets(
        pullRequest: PullRequest,
        jira: JiraService
    ) throws {
        let buildType: String = {
            guard pullRequest.base.ref.hasPrefix("release")
                else { return "Development" }
            return "Release"
        }()

        let title = pullRequest.title

        let pattern = try NSRegularExpression(pattern: "(" + Constants.jiraProjectPrefixPattern + ")-([0-9]{1,})(#[0-9]{0,})?", options: [])
        let titleRange = NSRange(location: 0, length: title.utf16.count)

        var error: Error?

        for matches in pattern.matches(in: title, options: [], range: titleRange) {
            // Skip if we has matched the "do not move" indicator.
            guard matches.range(at: 3).length == 0 else { continue }

            guard let prefixRange = Range(matches.range(at: 1), in: title),
                let numberRange = Range(matches.range(at: 2), in: title),
                let project = Constants.jiraProjects.first(where: { $0.prefix == title[prefixRange] }) else {
                #warning("TODO error")
                return
            }

            let prefix = title[prefixRange]
            let ticketId = prefix + "-" + title[numberRange]
            do {
                guard let issue = try jira.search("key = \(ticketId)").first
                    else { continue }

                #warning("TODO should be IssueType")
                let getTransitionId: (String) -> Int
                #warning("TODO")
                let action = PullRequestAcion.opened
                switch action {
                case .closed:
                    // Move the tickets to "Awaiting Build" if the PR is merged.
                    guard context.isMerged
                        else { return }
                    getTransitionId = { ($0 == .subtask && project != JiraService.Project.avalon)
                        ? project.transactionIds.done
                        : project.transactionIds.awaitingBuild
                    }

                case .labeled, .unlabeled, .opened:
                    #warning("TODO we don't care about label, check for draft/published")
//                        let labels = try github.getLabels(forPullRequestNumber: context.pullRequest.number)
//                        if labels.contains(Label.readyForReview) {
//                            // Move the tickets to "Peer Review" if the PR is ready for review.
                        getTransitionId = { _ in project.transactionIds.peerReview }
//                        } else if labels.contains(Label.workInProgress) {
//                            // Move the tickets to "In Progress" if the PR is a WIP.
//                            getTransitionId = { _ in project.transactionIds.inProgress }
//                        } else {
//                            return
//                        }
                case .assigned,
                     .unassigned,
                     .reviewRequested,
                     .reviewRequestRemoved,
                     .edited,
                     .reopened,
                     .synchronize:
                    return
                }

                let transitionId = getTransitionId(issue.type)

                try jira.moveTickets(
                    forTicketId: String(ticketId),
                    transitionId: transitionId
                )

                if transitionId == project.transactionIds.awaitingBuild {
                    try? jira.addLabel(forTicketId: String(ticketId), label: buildType)
                }
            } catch let innerError {
                error = innerError
            }
        }
    }
}
