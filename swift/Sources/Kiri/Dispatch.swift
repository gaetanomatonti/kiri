import Foundation
import KiriFFI

@_cdecl("swift_dispatch")
  public func dispatch(
  handlerId: UInt16,
  requestPointer: UnsafePointer<UInt8>?,
  requestLength: Int,
  completionContext: UnsafeMutableRawPointer?
) {
  guard let completionContext else {
    return
  }

  let completionToken = CompletionToken(completionContext)

  guard let requestPointer, requestLength > 0 else {
    completionToken.complete(.internalServerError("bad request frame"))
    return
  }

  let requestData = Data(bytes: requestPointer, count: requestLength)

  guard let request = FrameCodec.decodeRequest(requestData) else {
    completionToken.complete(.internalServerError("cannot decode request"))
    return
  }

  guard let handler = RouteRegistry.shared.handler(for: handlerId) else {
    completionToken.complete(.internalServerError("missing handler"))
    return
  }

  Task {
    let response = await handler(request)
    completionToken.complete(response)
  }
}

fileprivate final class CompletionToken: @unchecked Sendable {
  private let lock = NSLock()
  private var context: UnsafeMutableRawPointer?

  init(_ context: UnsafeMutableRawPointer?) {
    self.context = context
  }

  @discardableResult
  func complete(_ response: Response) -> Bool {
    lock.lock()
    let context = context.take()
    lock.unlock()

    guard let context else {
      return false
    }

    let data = FrameCodec.encodeResponse(response)
    data.withUnsafeBytes { raw in
      let pointer = raw.bindMemory(to: UInt8.self).baseAddress
      rust_complete(context, pointer, data.count)
    }
    return true
  }
}
