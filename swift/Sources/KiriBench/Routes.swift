import Foundation
import Kiri

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

func spin(_ request: Request) async throws -> Response {
  for i in 0..<1_000_000_000 {
    if i % 20_000_000 == 0 {
      try request.cancellation.throwIfCancelled()
    }
  }

  return .ok("done\n")
}
