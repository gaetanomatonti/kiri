public typealias Next = @Sendable (Request) async throws -> Response

public typealias Middleware = @Sendable (Request, Next) async throws -> Response
