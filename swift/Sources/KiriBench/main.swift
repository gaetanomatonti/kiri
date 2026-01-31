import Foundation
import Kiri

let app = App(port: 8080)
app.start()

app.get("/", get)
app.get("/hello", getHello)
app.get("/slow", slow)

app.run()

func get(_ request: Request) async -> Response {
  .ok("ok")
}

func getHello(_ request: Request) async -> Response {
  .ok("Hello, World!")
}

func slow(_ request: Request) async throws -> Response {
  try await Task.sleep(nanoseconds: 10_000_000_000)
  return .init(status: 504, body: Data("should not be here".utf8))
}
