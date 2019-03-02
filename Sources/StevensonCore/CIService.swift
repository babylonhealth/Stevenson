import Vapor

public protocol CIService: Service {
    func run(command: Command, on request: Worker) -> Future<String>
}
