import Foundation
import Kiri

let server = Server(port: 8080)
server.start()

for i in 1...5 {
  print(i)
  Thread.sleep(forTimeInterval: 1)
}

server.stop()
