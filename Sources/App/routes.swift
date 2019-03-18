import Vapor
import StevensonCore

/// Register your application's routes here.
public func routes(
    router: Router,
    commandHandler: CommandHandler
) throws {
    router.get { req in
        return "It works!"
    }

    router.post(any) { req throws -> Future<HTTPResponse> in
        try commandHandler.handle(commandFrom: req.http, on: req)
    }
}
