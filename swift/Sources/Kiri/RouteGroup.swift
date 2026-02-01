public struct RouteGroup {
  private let router: Router
  private let basePath: String
  private let parentMiddlewares: [Middleware]

  init(router: Router, basePath: String, middlewares: [Middleware]) {
    self.router = router
    self.basePath = basePath
    self.parentMiddlewares = middlewares
  }

  public func group(_ prefix: String, _ middlewares: Middleware...,  configure: (RouteGroup) -> Void) {
    let nextBase = Path.join(basePath, prefix)
    configure(
      RouteGroup(
        router: router,
        basePath: nextBase,
        middlewares: parentMiddlewares + middlewares
      )
    )
  }

  public func get(_ path: String, _ middlewares: Middleware..., handler: @escaping RouteHandler) {
    register(
      method: .get,
      path: path,
      middlewares: parentMiddlewares + middlewares,
      handler: handler
    )
  }

  func register(method: HttpMethod, path: String, middlewares: [Middleware], handler: @escaping RouteHandler) {
    router.registerGrouped(
      method: method,
      base: basePath,
      path: path,
      middlewares: middlewares,
      handler: handler
    )
  }
}
