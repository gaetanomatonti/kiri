import Foundation
import KiriFFI

public final class Router: @unchecked Sendable {
  enum Phase {
    case building
    case starting
    case started
  }

  let _router: UnsafeMutableRawPointer
  private let lock = NSLock()
  private var phase: Phase

  public init() {
    self._router = kiri_router_create()
    self.phase = .building
  }

  deinit {
    kiri_router_free(_router)
  }

  public func use(_ middleware: @escaping Middleware) {
    assertMutable()
    RouteRegistry.shared.addGlobal(middleware)
  }

  public func group(_ prefix: String, _ middlewares: Middleware..., configure: (RouteGroup) -> Void) {
    assertMutable()
    configure(RouteGroup(router: self, basePath: prefix, middlewares: middlewares))
  }

  public func register(_ method: HttpMethod, _ path: String, _ middlewares: [Middleware], handler: @escaping RouteHandler) {
    let routeId = RouteRegistry.shared.register(handler, middlewares: middlewares)
    registerRoute(method: method, pattern: path, routeId: routeId)
  }

  public func get(_ path: String, _ middlewares: Middleware..., handler: @escaping RouteHandler) {
    register(.get, path, middlewares, handler: handler)
  }

  func registerGrouped(
    method: HttpMethod,
    base: String,
    path: String,
    middlewares: [Middleware],
    handler: @escaping RouteHandler
  ) {
    register(method, Path.join(base, path), middlewares, handler: handler)
  }

  func beginStart() {
    lock.lock()
    defer { lock.unlock() }
    precondition(phase == .building, "Router already started/starting")
    phase = .starting
  }

  func commitStart() {
    lock.lock()
    defer { lock.unlock() }
    precondition(phase == .starting, "Invalid start transition")
    phase = .started
  }

  func rollbackStart() {
    lock.lock()
    defer { lock.unlock() }
    precondition(phase == .starting, "Invalid start rollback")
    phase = .building
  }

  private func registerRoute(method: HttpMethod, pattern: String, routeId: RouteID) {
    assertMutable()

    let normalizedPath = Path.join("", pattern)
    guard let patternData = normalizedPath.data(using: .utf8) else {
      return
    }

    let rc: Int32 = patternData.withUnsafeBytes { buffer in
      // Convert the pattern string to a bytes pointer
      let pointer = buffer.bindMemory(to: UInt8.self).baseAddress

      return kiri_router_register_route(
        _router,
        method.rawValue,
        pointer,
        patternData.count,
        routeId
      )
    }

    precondition(rc == 0, "register_route failed: \(rc)")
  }

  private func assertMutable(_ function: StaticString = #function) {
    lock.lock()
    defer { lock.unlock() }

    precondition(phase == .building, "Router is not mutable (\(phase)) when calling \(function)")
  }

  /// Registers routes for benchmarking purposes.
  /// These routes will be handled by Rust to measure the overhead of the Swift library.
  package func _registerBenchmarksRoutes() {
    registerRoute(method: .get, pattern: "/__rust/plaintext", routeId: UInt64.max)
    registerRoute(method: .get, pattern: "/__rust/noop", routeId: UInt64.max - 1)
  }
}
