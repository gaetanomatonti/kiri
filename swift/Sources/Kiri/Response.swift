import Foundation

public struct Response {
  public let status: StatusCode
  public let body: Data

  public init(status: StatusCode, body: Data) {
    self.status = status
    self.body = body
  }

  public static func ok(_ text: String) -> Response {
    Response(status: 200, body: Data(text.utf8))
  }

  public static func internalServerError(_ text: String) -> Response {
    Response(status: 500, body: Data(text.utf8))
  }
}
