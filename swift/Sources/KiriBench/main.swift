import Foundation
import Kiri

let app = App(port: 8080)
app.start()

app.get("/", getHello)
app.get("/hello", getHello)

app.run()

func getHello(_ request: Request) async throws -> Response {
  print(request)
  return Response()
}
