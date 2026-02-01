use std::sync::Arc;

pub unsafe fn arc_from_borrowed_ptr<T>(ptr: *const T) -> Arc<T> {
    unsafe {
        Arc::increment_strong_count(ptr);
        Arc::from_raw(ptr)
    }
}
