import Vapor

public protocol CIService {
    func run(command: Command, on request: Worker) -> Future<String>
}
