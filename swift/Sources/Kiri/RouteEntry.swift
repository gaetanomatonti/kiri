struct RouteEntry {
  let handler: RouteHandler
  let middlewares: [Middleware]
}
