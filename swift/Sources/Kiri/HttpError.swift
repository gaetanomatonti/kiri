import Foundation

public struct HttpError: Error {
  public let status: StatusCode
  public let body: Data

  public init(status: StatusCode, body: Data) {
    self.status = status
    self.body = body
  }
}
