import KiriFFI

final public class Server {
  typealias ServerHandle = UnsafeMutableRawPointer

  let port: UInt16

  private var serverHandle: ServerHandle?

  public init(port: UInt16) {
    self.port = port
  }

  deinit {
    stop()
  }

  public func start() {
    guard serverHandle == nil else {
      return
    }

    serverHandle = server_start(port)
  }

  public func stop() {
    guard let serverHandle else {
      return
    }

    server_stop(serverHandle)
    self.serverHandle = nil
  }
}
