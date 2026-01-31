import Foundation

public struct Request {
  public let method: HttpMethod
  public let path: String
  public let body: Data
  public let cancellation: CancellationToken

  init(from decodedRequest: FrameCodec.DecodedRequest, cancellation cancellationToken: CancellationToken) {
    #warning("Make Request throw an error if the HttpMethod could not be initialized.")
    method = HttpMethod(rawValue: decodedRequest.method)!
    path = decodedRequest.path
    body = decodedRequest.body
    cancellation = cancellationToken
  }
}
