import Vapor
import StevensonCore

/// Register your application's routes here.
public func routes(
    router: Router,
    ci: CIService,
    commandHandler: CommandHandler
) throws {
    router.get { req in
        return "It works!"
    }

    router.post(any) { req throws -> Future<HTTPResponse> in
        let command = try commandHandler.command(from: req.http)
        if command.name == Command.helpCommandName {
            let result = try commandHandler.result(from: command.arguments[Command.helpCommandText] ?? "")
            return req.future(result)
        } else {
            return ci.run(command: command, on: req).map(commandHandler.result(from:))
        }
    }
}
