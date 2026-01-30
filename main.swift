import Foundation

@_silgen_name("server_start")
func startServer(_ port: UInt16) -> UnsafeMutableRawPointer?

@_silgen_name("server_stop")
func stopServer(_ handle: UnsafeMutableRawPointer?)

print("[Swift] starting server")
let handle = startServer(8080)
print("[Swift] server started on 127.0.0.1:8080")

for i in 1...5 {
  print(i)
  Thread.sleep(forTimeInterval: 1)
}

stopServer(handle)
print("[Swift] server stopped")
