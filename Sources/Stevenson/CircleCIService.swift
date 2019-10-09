import Vapor

public struct CircleCIService {
    private let baseURL = URL(string: "https://circleci.com")!
    private let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]

    public let token: String

    public init(token: String) {
        self.token = token
    }

}

extension CircleCIService {

    struct BuildRequest: Content {
        let buildParameters: [String: String]

        enum CodingKeys: String, CodingKey {
            case buildParameters = "build_parameters"
        }
    }

    public struct BuildResponse: Content {
        public let branch: String
        public let buildURL: String

        enum CodingKeys: String, CodingKey {
            case branch
            case buildURL = "build_url"
        }
    }

    private func buildURL(project: String, branch: String) -> URL {
        return URL(
            string: "/api/v1.1/project/github/\(project)/tree/\(branch)?circle-token=\(token)",
            relativeTo: baseURL
        )!
    }

    public func job(
        parameters: [String: String],
        project: String,
        branch: String,
        on container: Container
    ) throws -> Future<BuildResponse> {
        let url = buildURL(project: project, branch: branch)
        return try request(.capture()) {
            try container.client().post(url, headers: headers) {
                try $0.content.encode(BuildRequest(buildParameters: parameters))
            }
        }
    }

}

extension CircleCIService {

    public struct PipelineRequest: Encodable {
        let branch: String
        let parameters: [String: Parameter]

        public enum Parameter: Encodable {
            case bool(Bool)
            case string(String)

            public func encode(to encoder: Encoder) throws {
                var values = encoder.singleValueContainer()
                switch self {
                case let .bool(value):
                    try values.encode(value)
                case let .string(value):
                    try values.encode(value)
                }
            }
        }
    }

    public struct PipelineResponse: Content {
        public let branch: String
        public let buildURL: URL
    }

    struct PipelineID: Content {
        let id: String
    }

    struct Pipeline: Content {
        let workflows: [Workflow]
        let vcs: VCS

        struct Workflow: Content {
            let id: String
        }

        struct VCS: Content {
            let branch: String
        }
    }

    private func pipelineURL(project: String) -> URL {
        return URL(
            string: "/api/v2/project/github/\(project)/pipeline?circle-token=\(token)",
            relativeTo: baseURL
        )!
    }

    private func pipelineURL(pipelineID: String) -> URL {
        return URL(
            string: "/api/v2/pipeline/\(pipelineID)?circle-token=\(token)",
            relativeTo: baseURL
        )!
    }

    private func workflowURL(workflowID: String) -> URL {
        return URL(
            string: "/workflow-run/\(workflowID)",
            relativeTo: baseURL
        )!
    }

    public func pipeline(
        parameters: [String: PipelineRequest.Parameter],
        project: String,
        branch: String,
        on container: Container
    ) throws -> Future<PipelineResponse> {
        let url = pipelineURL(project: project)

        return try request(.capture()) {
            try container.client().post(url, headers: headers) {
                try $0.content.encode(json: PipelineRequest(branch: branch, parameters: parameters))
            }
        }.map { (pipelineID: PipelineID) in
            self.pipelineURL(pipelineID: pipelineID.id)
        }.flatMap { pipelineURL in
            // workflows are not created immediately so we wait a bit
            // hoping that when we request pipeline the workflow id will be there
            sleep(2)
            return try self.request(.capture()) {
                try container.client().get(pipelineURL, headers: self.headers)
            }
        }.map { (pipeline: Pipeline) in
            PipelineResponse(
                branch: pipeline.vcs.branch,
                buildURL: pipeline.workflows.first.map {
                    self.workflowURL(workflowID: $0.id).absoluteURL
                } ?? self.baseURL
            )
        }
    }
}
