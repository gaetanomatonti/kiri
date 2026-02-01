import Foundation
import KiriFFI

struct ServerError: Error, LocalizedError {
  let message: String

  var errorDescription: String? {
    message
  }

  init(_ message: String) {
    self.message = message
  }
}

final class Server {
  typealias ServerHandle = UnsafeMutableRawPointer

  let port: UInt16

  private var serverHandle: ServerHandle?

  private let router: Router

  init(port: UInt16, router: Router) {
    self.port = port
    self.router = router
  }

  deinit {
    stop()
  }

  func start() throws {
    guard serverHandle == nil else {
      return
    }

    serverHandle = server_start_with_router(port, router._router)

    guard serverHandle != nil else {
      throw ServerError(lastError() ?? "Unexpected error")
    }
  }

  func stop() {
    guard let serverHandle else {
      return
    }

    server_stop(serverHandle)
    self.serverHandle = nil
  }
}
