#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

void* server_start(uint16_t port);
void* server_start_with_router(uint16_t port, void* router);
void server_stop(void* handle);

void* router_create(void);
void router_free(void *router);
int32_t router_register_route(
  void* router,
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
