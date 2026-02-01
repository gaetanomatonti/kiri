public struct RouteGroup {
  private let router: Router
  private let basePath: String

  init(router: Router, basePath: String) {
    self.router = router
    self.basePath = basePath
  }

  public func group(_ prefix: String, configure: (RouteGroup) -> Void) {
    let nextBase = Path.join(basePath, prefix)
    configure(RouteGroup(router: router, basePath: nextBase))
  }

  public func get(_ path: String, _ handler: @escaping RouteHandler) {
    register(.get, path: path, handler)
  }

  func register(_ method: HttpMethod, path: String, _ handler: @escaping RouteHandler) {
    router.registerGrouped(method: method, base: basePath, path: path, handler)
  }
}
