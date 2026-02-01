import Foundation

final class RouteRegistry: @unchecked Sendable {
  public static let shared = RouteRegistry()

  private let lock = NSLock()

  private var nextId: RouteID

  private var handlers: [RouteID: RouteHandler]

  private init() {
    nextId = 0
    handlers = [:]
  }

  func register(_ handler: @escaping RouteHandler) -> RouteID {
    lock.lock()
    let id = nextId
    defer {
      nextId += 1
      lock.unlock()
    }

    handlers[id] = handler
    return id
  }

  func handler(for id: RouteID) -> RouteHandler? {
    lock.lock()
    defer {
      lock.unlock()
    }

    let handler = handlers[id]
    return handler
  }
}
