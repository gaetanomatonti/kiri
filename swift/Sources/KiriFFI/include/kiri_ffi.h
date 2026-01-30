#pragma once
#include <stdint.h>
#include <stddef.h>

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
