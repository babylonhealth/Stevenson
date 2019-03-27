import Vapor

public protocol CIService {
    func run(command: Command, on worker: Request) throws -> Future<String>
}
