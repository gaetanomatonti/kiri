import Logging
import Vapor

@main
enum Entrypoint {
  static func main() async throws {
    LoggingSystem.bootstrap(SwiftLogNoOpLogHandler.init)

    let app = try await Application.make(.production)

    app.http.server.configuration.port = 8080

    app.get("noop") { _ -> Response in
      Response(status: .noContent)
    }

    app.get("plaintext") { _ -> Response in
      var headers = HTTPHeaders()
      headers.add(name: .contentType, value: "text/plain; charset=utf-8")
      return Response(
        status: .ok,
        headers: headers,
        body: .init(string: "Hello, World!")
      )
    }

    do {
      try await app.execute()
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }
}
