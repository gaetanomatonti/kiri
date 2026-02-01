import Foundation
import Kiri

do {
  let router = Router()
  router.get("", get)

  router.group("api") { api in
    api.get("hello", getHello)

    api.group("test") { test in
      test.get("/slow", slow)
      test.get("spin", spin)
    }
  }

  let app = App(port: 8080, router: router)
  try app.run()
} catch {
  print(error.localizedDescription)
}
