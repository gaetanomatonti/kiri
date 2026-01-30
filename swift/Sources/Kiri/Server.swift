import KiriFFI

final class Server {
  typealias ServerHandle = UnsafeMutableRawPointer

  let port: UInt16

  private var serverHandle: ServerHandle?

  init(port: UInt16) {
    self.port = port
  }

  deinit {
    stop()
  }

  func start() {
    guard serverHandle == nil else {
      return
    }

    serverHandle = server_start(port)
  }

  func stop() {
    guard let serverHandle else {
      return
    }

    server_stop(serverHandle)
    self.serverHandle = nil
  }

  func registerRoute(method: HttpMethod, pattern: String, routeId: RouteRegistry.RouteID) {
    guard let serverHandle else {
      return
    }

    guard let patternData = pattern.data(using: .utf8) else {
      print("Failed to parse pattern \(pattern) into bytes")
      return
    }

    let rc: Int32 = patternData.withUnsafeBytes { buffer in
      // Convert the pattern string to a bytes pointer
      let pointer = buffer.bindMemory(to: UInt8.self).baseAddress

      return register_route(
        serverHandle,
        method.rawValue,
        pointer,
        patternData.count,
        routeId
      )
    }

    print("[Swift] Mapped \(method) \(pattern)")
    precondition(rc == 0, "register_route failed: \(rc)")
  }
}
