import Foundation
import Kiri

func logger() -> Middleware {
  return { request, next in
    print("Executing \(request.method) \(request.path)")
    let response = try await next(request)
    print("\(request.method) \(request.path) - \(response.status)")
    if let body = String(data: response.body, encoding: .utf8) {
      print(body)
    }
    return response
  }
}

do {
  let router = Router()
  router.use(logger())

  router.get("", handler: get)

  router.group("api") { api in
    api.get("hello", handler: getHello)

    api.group("test", configure: { test in
      test.get("slow", handler: slow)
      test.get("spin", handler: spin)
    })
  }

  let app = App(port: 8080, router: router)
  try app.run()
} catch {
  print(error.localizedDescription)
}
