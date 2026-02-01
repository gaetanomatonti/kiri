import KiriFFI

func lastError() -> String? {
  guard let message = kiri_last_error_message() else {
    return nil
  }

  defer {
    kiri_last_error_message_free(message)
  }

  return String(cString: message)
}
