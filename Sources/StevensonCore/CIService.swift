import Vapor

public protocol CIService {
    func run(command: Command, on worker: Worker) throws -> Future<String>
}
