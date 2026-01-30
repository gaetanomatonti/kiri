public enum HttpMethod: UInt8, CustomDebugStringConvertible {
  case get = 0

  public var debugDescription: String {
    switch self {
      case .get:
        return "GET"
    }
  }
}
