import KiriFFI

public final class Router: @unchecked Sendable {
  let _router: UnsafeMutableRawPointer

  public init() {
    self._router = router_create()
  }

  deinit {
    router_free(_router)
  }

  public func get(_ path: String, _ handler: @escaping RouteHandler) {
    let routeId = RouteRegistry.shared.register(handler)
    registerRoute(method: .get, pattern: path, routeId: routeId)
  }

  func registerRoute(method: HttpMethod, pattern: String, routeId: RouteID) {
    guard let patternData = pattern.data(using: .utf8) else {
      print("Failed to parse pattern \(pattern) into bytes")
      return
    }

    let rc: Int32 = patternData.withUnsafeBytes { buffer in
      // Convert the pattern string to a bytes pointer
      let pointer = buffer.bindMemory(to: UInt8.self).baseAddress

      return router_register_route(
        _router,
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
