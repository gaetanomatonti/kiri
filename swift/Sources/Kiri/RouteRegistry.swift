import Foundation

final class RouteRegistry: @unchecked Sendable {
  public static let shared = RouteRegistry()

  private let lock = NSLock()
  private var nextId: RouteID
  private var entries: [RouteID: RouteEntry]
  private var middlewares: [Middleware]

  private init() {
    nextId = 0
    entries = [:]
    middlewares = []
  }

  func addGlobal(_ middleware: @escaping Middleware) {
    lock.lock()
    defer {
      lock.unlock()
    }

    middlewares.append(middleware)
  }

  func globalMiddlewares() -> [Middleware] {
    lock.lock()
    defer {
      lock.unlock()
    }

    return middlewares
  }

  func register(_ handler: @escaping RouteHandler, middlewares: [Middleware]) -> RouteID {
    lock.lock()
    defer {
      nextId += 1
      lock.unlock()
    }

    let id = nextId
    entries[id] = RouteEntry(handler: handler, middlewares: middlewares)
    return id
  }

  func entry(for id: RouteID) -> RouteEntry? {
    lock.lock()
    defer {
      lock.unlock()
    }

    let entry = entries[id]
    return entry
  }
}
