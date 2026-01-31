import Foundation
import KiriFFI

/// This functions is called by the Rust runtime when it receives a request,
// delegating the needed handling to Swift.
// Rust passes a `completionContext` to communicate the completion of the request from the Swift runtime to Rust's.
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

  // Wrap the pointer into a completion token, to make sure we complete (and free the pointer) exactly once.
  // This is necessary because only Swift is responsible for freeing the context pointer,
  // so freeing multiple times can cause double free/use-after-free.
  let completionToken = CompletionToken(completionContext)

  guard let requestPointer, requestLength > 0 else {
    completionToken.complete(with: .internalServerError("bad request frame"))
    return
  }

  let requestData = Data(bytes: requestPointer, count: requestLength)

  guard let request = FrameCodec.decodeRequest(requestData) else {
    completionToken.complete(with: .internalServerError("cannot decode request"))
    return
  }

  guard let handle = RouteRegistry.shared.handler(for: handlerId) else {
    completionToken.complete(with: .internalServerError("missing handler"))
    return
  }

  Task {
    let response = await handle(request)
    completionToken.complete(with: response)
  }
}

fileprivate final class CompletionToken: @unchecked Sendable {
  private let lock = NSLock()
  private var context: UnsafeMutableRawPointer?

  init(_ context: UnsafeMutableRawPointer?) {
    self.context = context
  }

  @discardableResult
  func complete(with response: Response) -> Bool {
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
