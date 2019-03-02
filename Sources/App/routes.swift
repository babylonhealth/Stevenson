import Vapor
import StevensonCore

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get { req in
        return "It works!"
    }

    router.post(PathComponent.anything) { req throws -> Future<HTTPResponse> in
        let ci = try req.sharedContainer.make(CIService.self)
        let handler = try req.sharedContainer.make(CommandHandler.self)
        let command = try handler.command(from: req.http)
        if command.name == Command.helpCommandName {
            let result = try handler.result(from: command.arguments[Command.helpCommandText] ?? "")
            return req.future(result)
        } else {
            return ci.run(command: command, on: req).map(handler.result(from:))
        }
    }
}
