import Foundation
import Kiri
import Logging

#if KIRI_BENCH
LoggingSystem.bootstrap(SwiftLogNoOpLogHandler)
#else
LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
#endif

fileprivate let logger = Logger(label: "com.kiri-bench")
let router = Router()
router.use(.logging)

router.get("/", handler: getHello)

#if KIRI_BENCH
router.get("noop", handler: noop)
router.get("plaintext", handler: plaintext)
router._registerBenchmarksRoutes()
#endif

let port: UInt16 = 8080
let app = App(port: port, router: router)

do {
  try app.run()
  logger.info("Server running on port: \(port)")
} catch {
  logger.error("Failed to start server: \(error.localizedDescription)")
}
