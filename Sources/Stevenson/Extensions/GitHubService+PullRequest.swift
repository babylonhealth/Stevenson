import Vapor

extension GitHubService {
    public struct PullRequestEvent: Content {
        let context: PullRequestContext
        let action: PullRequest.Action
    }

    public struct PullRequestContext: Content {
        // NOTE: This is an undocumented property sent by the API which means can break in the future but is more
        // efficient than doing multiple checks to determine this
        //
        // Reference: https://github.com/octokit/octokit.net/pull/1764/files
        enum MergeState: String, Content {
            /// Merge conflict. Merging is blocked.
            case dirty
            /// Mergeability was not checked yet. Merging is blocked.
            case unknown
            /// Failing/missing required status check. Merging is blocked.
            case blocked
            /// Head branch is behind the base branch. Only if required status checks is enabled but loose policy is not. Merging is blocked.
            case behind
            /// Failing/pending commit status that is not part of the required status checks. Merging is still allowed.
            case unstable
            /// No conflicts, everything good. Merging is allowed.
            case clean
            /// draft
            case draft
        }

        let pullRequest: PullRequest
        let isMerged: Bool
        let mergeState: MergeState
    }
}

extension GitHubService {
    public struct PullRequest: Content {
        public enum Action: String, Content {
            case assigned
            case unassigned
            case reviewRequested = "review_requested"
            case reviewRequestRemoved = "review_request_removed"
            case labeled
            case unlabeled
            case opened
            case edited
            case closed
            case reopened
            case synchronize
        }

        struct Review: Content {
            enum State: String, Content {
                case approved = "APPROVED"
                case changeRequested = "REQUESTED_CHANGES"
                case dismissed = "DISMISSED"
                case pending = "PENDING"
            }

            let userId: Int
            let state: State
        }

        struct Label: Equatable {
            let id: Int
            let name: String
        }

//        let labels: [Label]

        public let number: Int
        public var repoFullname: String {
            head.repo.full_name
        }
        public let html_url: String
        public let title: String

        public struct Ref: Content {
            public struct Repo: Content {
                public let full_name: String
            }

            public let ref: String
            public let repo: Repo
        }
        public let head: Ref
        public let base: Ref
    }
}
