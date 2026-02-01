import Dispatch
import Foundation

final public class App {
  private let server: Server

  public init(port: UInt16, router: Router) {
    server = Server(port: port, router: router)
  }

  public func stop() {
    server.stop()
  }

  public func run() throws {
    try server.start()

    Process.run { [weak self] in
      print("\nStopping...")

      self?.stop()
    }
  }
}
