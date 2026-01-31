#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

void* server_start(uint16_t port);
void server_stop(void* handle);

int32_t register_route(
  void* handle,
  uint8_t method,
  const uint8_t* pattern,
  size_t pattern_len,
  uint16_t handler_id
);

void rust_complete(void* completion_ctx, const uint8_t* resp_ptr, size_t resp_len);
void rust_release(void *completion_ctx);
bool rust_is_cancelled(const void *completion_ctx);

char* last_error_message(void);
void last_error_message_free(char *s);
