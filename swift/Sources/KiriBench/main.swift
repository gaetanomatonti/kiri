import Foundation
import Kiri

do {
  let router = Router()
  router.get("/", get)
  router.get("/hello", getHello)
  router.get("/slow", slow)
  router.get("/spin", spin)

  let app = App(port: 8080, router: router)
  try app.run()
} catch {
  print(error.localizedDescription)
}
