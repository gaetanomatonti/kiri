pub fn matches(pattern: &str, path: &str) -> bool {
    let p = pattern.trim_matches('/');
    let s = path.trim_matches('/');

    if p.is_empty() && s.is_empty() {
        return true;
    }

    let p_segments: Vec<&str> = p.split('/').collect();
    let s_segments: Vec<&str> = s.split('/').collect();

    if p_segments.len() != s_segments.len() {
        return false;
    }

    for (pp, ss) in p_segments.iter().zip(s_segments.iter()) {
        if pp.starts_with(':') {
            continue;
        }
        if pp != ss {
            return false;
        }
    }

    return true;
}

pub fn method_to_u8(m: &hyper::Method) -> u8 {
    match *m {
        hyper::Method::GET => 0,
        _ => 255,
    }
}
