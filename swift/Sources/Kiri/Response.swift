import Foundation

public struct Response {
  public let status: UInt16
  public let body: Data

  public init(status: UInt16, body: Data) {
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
