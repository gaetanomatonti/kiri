import Logging

fileprivate let logger = Logger(label: "com.kiri-bench.logging-middleware")

public struct LoggingMiddleware: Middleware {
  public func handle(request: Request, next: (Request) async throws -> Response) async throws -> Response {
    var logger = logger
    logger[metadataKey: "request.method"] = .string(request.method.debugDescription)
    logger[metadataKey: "request.url"] = .string(request.path)

    logger.info("Executing request \(request.method) \(request.path)")
    let response = try await next(request)

    logger[metadataKey: "response.status"] = .stringConvertible(response.status)

    if let body = String(data: response.body, encoding: .utf8) {
      logger[metadataKey: "response.body"] = .string(body)
    }

    logger.info("\(request.method) \(request.path)")
    return response
  }
}

public extension Middleware where Self == LoggingMiddleware {
  static var logging: LoggingMiddleware {
    LoggingMiddleware()
  }
}
