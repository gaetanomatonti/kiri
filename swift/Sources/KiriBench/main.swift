import Foundation
import Kiri

do {
  let app = App(port: 8080)
  try app.start()

  app.get("/", get)
  app.get("/hello", getHello)
  app.get("/slow", slow)
  app.get("/spin", spin)

  app.run()
} catch {
  print(error.localizedDescription)
}
