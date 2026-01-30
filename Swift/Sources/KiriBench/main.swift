import Foundation
import Kiri

let handle = startServer(port: 8080)

Thread.sleep(forTimeInterval: 5)

stopServer(handle)
