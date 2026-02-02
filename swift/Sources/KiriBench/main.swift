import Foundation
import Kiri

do {
  let router = Router()

  #if KIRI_BENCH
  router.get("noop", handler: noop)
  router.get("plaintext", handler: plaintext)
  router._registerBenchmarksRoutes()
  #endif

  let app = App(port: 8080, router: router)
  try app.run()
} catch {
  print(error.localizedDescription)
}
