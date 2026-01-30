import Foundation
import Kiri

let app = App(port: 8080)
app.start()

app.get("/", get)
app.get("/hello", getHello)

app.run()

func get(_ request: Request) async -> Response {
  .ok("ok")
}

func getHello(_ request: Request) async -> Response {
  .ok("Hello, World!")
}
