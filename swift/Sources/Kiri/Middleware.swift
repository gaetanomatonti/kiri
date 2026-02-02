public typealias Next = @Sendable (Request) async throws -> Response

public protocol Middleware: Sendable {
  func handle(request: Request, next: Next) async throws -> Response
}
