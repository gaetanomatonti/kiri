import Foundation
import Kiri

func noop(_ request: Request) async -> Response {
  .noContent()
}

func plaintext(_ request: Request) async -> Response {
  .ok("Hello, World!")
}
