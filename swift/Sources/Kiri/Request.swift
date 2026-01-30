import Foundation

public struct Request {
  public let method: UInt8
  public let path: String
  public let body: Data
}
