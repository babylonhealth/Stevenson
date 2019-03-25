import Vapor

public protocol CIService {
    func run(command: Command, on worker: Worker) -> Future<String>
}
