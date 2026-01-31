import KiriFFI

func lastError() -> String? {
  guard let message = last_error_message() else {
    return nil
  }

  defer {
    last_error_message_free(message)
  }

  return String(cString: message)
}
