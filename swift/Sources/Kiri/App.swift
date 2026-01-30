import Dispatch
import Foundation

final public class App {
  private let server: Server

  public init(port: UInt16) {
    server = Server(port: port)
  }

  public func start() {
    server.start()
  }

  public func stop() {
    server.stop()
  }

  public func run() {
    Process.run { [weak self] in
      print("\nStopping...")

      self?.stop()
    }
  }

  public func get(_ pattern: String, _ handler: @escaping RouteHandler) {
    let routeId = RouteRegistry.shared.register(handler)
    server.registerRoute(method: .get, pattern: pattern, routeId: routeId)
  }
}
