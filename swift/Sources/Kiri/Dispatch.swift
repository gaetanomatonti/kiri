import Foundation
import KiriFFI

@_cdecl("swift_dispatch")
  public func dispatch(
  handlerId: UInt16,
  requestPointer: UnsafePointer<UInt8>?,
  requestLength: Int,
  completionContext: UnsafeMutableRawPointer?
) {
  guard let requestPointer, let completionContext else {
    return
  }

  let requestData = Data(bytes: requestPointer, count: requestLength)

  guard
    let request = FrameCodec.decodeRequest(requestData),
    let handler = RouteRegistry.shared.handler(for: handlerId)
  else {
    let response = FrameCodec.encodeResponse(.internalServerError("handler missing or bad request"))
    response.withUnsafeBytes { raw in
      #warning("This could be unsage. Make sure rust_complete is called exactly once per request.")
      rust_complete(completionContext, raw.bindMemory(to: UInt8.self).baseAddress, response.count)
    }
    return
  }

  let contextAddress = UInt(bitPattern: completionContext)
  Task {
    let response = await handler(request)
    let responseData = FrameCodec.encodeResponse(response)
    let context = UnsafeMutableRawPointer(bitPattern: contextAddress)

    responseData.withUnsafeBytes { raw in
      rust_complete(context, raw.bindMemory(to: UInt8.self).baseAddress, responseData.count)
    }
  }
}

// TODO: final class CompletionToken {}
