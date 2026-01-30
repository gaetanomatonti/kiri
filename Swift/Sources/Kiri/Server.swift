import KiriFFI

public typealias ServerHandle = UnsafeMutableRawPointer

public func startServer(port: UInt16) -> ServerHandle {
  server_start(port)
}

public func stopServer(_ handle: ServerHandle) {
  server_stop(handle)
}
