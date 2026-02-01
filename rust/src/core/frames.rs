use crate::core::types::StatusCode;

/*
* [u8  method]       -> 1
* [u32 path_len]     -> 4
* [bytes path UTF-8] -> bytes.len
* [u32 body_len]     -> 4
* [bytes body]       -> bytes.len
*/
pub fn encode_request(method: u8, path: &str, body: &[u8]) -> Vec<u8> {
    let path_bytes = path.as_bytes();
    let mut out = Vec::with_capacity(1 + 4 + path_bytes.len() + 4 + body.len());
    out.push(method);
    out.extend_from_slice(&(path_bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(path_bytes);
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(body);
    return out;
}

pub fn decode_response(bytes: &[u8]) -> Option<(StatusCode, Vec<u8>)> {
    if bytes.len() < 6 {
        return None;
    }

    let status = StatusCode::from_le_bytes([bytes[0], bytes[1]]);
    let body_len = u32::from_le_bytes([bytes[2], bytes[3], bytes[4], bytes[5]]) as usize;
    if bytes.len() < 6 + body_len {
        return None;
    }

    return Some((status, bytes[6..6 + body_len].to_vec()));
}
