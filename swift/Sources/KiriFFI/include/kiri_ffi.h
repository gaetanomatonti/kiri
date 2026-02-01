#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

void* kiri_server_start(uint16_t port);
void* kiri_server_start_with_router(uint16_t port, void* router);
void kiri_server_stop(void* handle);

void* kiri_router_create(void);
void kiri_router_free(void *router);
int32_t kiri_router_register_route(
  void* router,
  uint8_t method,
  const uint8_t* pattern,
  size_t pattern_len,
  uint64_t handler_id
);

void kiri_request_complete(void* completion_ctx, const uint8_t* resp_ptr, size_t resp_len);
void kiri_request_free(void *completion_ctx);
bool kiri_request_is_cancelled(const void *completion_ctx);
void kiri_cancellation_free(void *completion_ctx);

char* kiri_last_error_message(void);
void kiri_last_error_message_free(char *s);
