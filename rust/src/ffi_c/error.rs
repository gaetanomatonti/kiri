use std::{cell::RefCell, ffi::CString, os::raw::c_char};

thread_local! {
  static LAST_ERROR: RefCell<Option<CString>> = RefCell::new(None);
}

pub fn set_last_error(message: String) {
    let c = CString::new(message).unwrap_or_else(|_| CString::new("Unknown error").unwrap());
    LAST_ERROR.with(|slot| {
        *slot.borrow_mut() = Some(c);
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn last_error_message() -> *mut c_char {
    LAST_ERROR.with(|slot| {
        slot.borrow()
            .as_ref()
            .map(|c| c.clone().into_raw())
            .unwrap_or(std::ptr::null_mut())
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn last_error_message_free(s: *mut c_char) {
    if s.is_null() {
        return;
    }

    unsafe {
        drop(CString::from_raw(s));
    }
}
