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

  let port: Port

  private var serverHandle: ServerHandle?

  private let router: Router

  init(port: Port, router: Router) {
    self.port = port
    self.router = router
  }

  deinit {
    stop()
  }

  func start() throws {
    router.beginStart()

    do {
      try startWithRouter()
    } catch {
      router.rollbackStart()
      throw error
    }

    router.commitStart()
  }

  func stop() {
    guard let serverHandle else {
      return
    }

    kiri_server_stop(serverHandle)
    self.serverHandle = nil
  }

  private func startWithRouter() throws {
    guard serverHandle == nil else {
      return
    }

    serverHandle = kiri_server_start_with_router(port, router._router)

    guard serverHandle != nil else {
      throw ServerError(lastError() ?? "Unexpected error")
    }
  }
}
