import Foundation

final class RouteRegistry {
  typealias RouteID = UInt16

  private let lock = NSLock()

  #warning("This is not safe if multiple app instances are running in the same program.")
  private var nextId: RouteID

  private var handlers: [RouteID: RouteHandler]

  init() {
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
