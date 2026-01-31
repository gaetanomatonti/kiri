import Foundation

enum FrameCodec {
  static func decodeRequest(_ data: Data) -> Request? {
    var i = 0
    func u8() -> UInt8? { guard i+1 <= data.count else { return nil }; defer { i+=1 }; return data[i] }
    func u32() -> UInt32? {
      guard i+4 <= data.count else { return nil }
      let v = UInt32(data[i]) | (UInt32(data[i+1])<<8) | (UInt32(data[i+2])<<16) | (UInt32(data[i+3])<<24)
      i += 4; return v
    }
    func bytes(_ n: Int) -> Data? { guard i+n <= data.count else { return nil }; defer { i += n }; return data.subdata(in: i..<(i+n)) }

    guard let method = u8(),
      let pathLen = u32(),
      let pathBytes = bytes(Int(pathLen)),
      let path = String(data: pathBytes, encoding: .utf8),
      let bodyLen = u32(),
      let body = bytes(Int(bodyLen))
      else { return nil }

    return Request(method: method, path: path, body: body)
  }

  static func encodeResponse(_ resp: Response) -> Data {
    var out = Data()
    out.append(UInt8(resp.status & 0xff))
    out.append(UInt8((resp.status >> 8) & 0xff))

    let len = UInt32(resp.body.count)
    out.append(UInt8(len & 0xff))
    out.append(UInt8((len >> 8) & 0xff))
    out.append(UInt8((len >> 16) & 0xff))
    out.append(UInt8((len >> 24) & 0xff))
    out.append(resp.body)
    return out
  }
}
