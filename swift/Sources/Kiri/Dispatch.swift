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
  completionContext: UnsafeMutableRawPointer?,
  cancellationHandle: UnsafeMutableRawPointer?,
) {
  // Wrap the pointer into a completion token, to make sure we complete (and free the pointer) exactly once.
  // This is necessary because only Swift is responsible for freeing the context pointer,
  // so freeing multiple times can cause double free/use-after-free.
  let completionToken = CompletionToken(completionContext)
  let cancellationHandle = CancellationHandle(cancellationHandle)

  guard let requestPointer, requestLength > 0 else {
    completionToken.complete(
      with: .internalServerError("bad request frame"),
      cancellation: cancellationHandle,
    )
    return
  }

  let requestData = Data(bytes: requestPointer, count: requestLength)
  guard let decodedRequest = FrameCodec.decodeRequest(requestData) else {
    completionToken.complete(
      with: .internalServerError("cannot decode request"),
      cancellation: cancellationHandle,
    )
    return
  }

  let request = Request(
    from: decodedRequest,
    cancellation: CancellationToken(handle: cancellationHandle),
  )

  guard let handle = RouteRegistry.shared.handler(for: handlerId) else {
    completionToken.complete(
      with: .internalServerError("missing handler"),
     cancellation: cancellationHandle,
    )
    return
  }

  Task {
    do {
      let response = try await handle(request)
      completionToken.complete(with: response, cancellation: cancellationHandle)
    } catch let error as HttpError {
      completionToken.complete(
        with: Response(status: error.status, body: error.body),
        cancellation: cancellationHandle,
      )
    } catch is CancellationError {
      print("\(request.method) \(request.path) - cancelled")

      completionToken.complete(
        with: Response(status: 499, body: Data()),
        cancellation: cancellationHandle,
      )
    } catch {
      completionToken.complete(
        with: .internalServerError("Caught unhandled error: \(error.localizedDescription)"),
        cancellation: cancellationHandle,
      )
    }
  }
}

fileprivate final class CompletionToken: @unchecked Sendable {
  private let lock = NSLock()
  private var context: UnsafeMutableRawPointer?

  init(_ context: UnsafeMutableRawPointer?) {
    self.context = context
  }

  deinit {
    release()
  }

  func complete(with response: Response, cancellation: CancellationHandle) {
    guard let context = takeContext() else {
      return
    }

    // If the request is cancelled, release the completion context.
    if cancellation.rawPointer.map({ rust_is_cancelled($0) }) ?? true {
      rust_release(context)
      return
    }

    let data = FrameCodec.encodeResponse(response)
    data.withUnsafeBytes { raw in
      let pointer = raw.bindMemory(to: UInt8.self).baseAddress
      rust_complete(context, pointer, data.count)
    }
    return
  }

  private func takeContext() -> UnsafeMutableRawPointer? {
    lock.lock()
    defer {
      lock.unlock()
    }

    return context.take()
  }

  private func release() {
    guard let context = takeContext() else {
      return
    }

    rust_release(context)
  }
}

public struct CancellationToken: Sendable {
  fileprivate let handle: CancellationHandle

  public var isCancelled: Bool {
    guard let pointer = handle.rawPointer else {
      return true
    }

    return rust_is_cancelled(pointer)
  }

  public func throwIfCancelled() throws {
    if isCancelled {
      throw CancellationError()
    }
  }
}

public struct CancellationError: Error {}

fileprivate final class CancellationHandle: @unchecked Sendable {
  private var pointer: UnsafeMutableRawPointer?

  var rawPointer: UnsafeRawPointer? {
    UnsafeRawPointer(pointer)
  }

  init(_ pointer: UnsafeMutableRawPointer?) {
    self.pointer = pointer
  }

  deinit {
    if let pointer = pointer.take() {
      rust_release(pointer)
    }
  }
}
