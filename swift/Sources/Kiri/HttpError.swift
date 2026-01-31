import Foundation

public struct HttpError: Error {
  public let status: UInt16
  public let body: Data

  public init(status: UInt16, body: Data) {
    self.status = status
    self.body = body
  }
}
