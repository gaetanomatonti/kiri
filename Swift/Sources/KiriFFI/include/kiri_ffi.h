#pragma once
#include <stdint.h>
#include <stddef.h>

void* server_start(uint16_t port);
void server_stop(void* handle);
