# Kiri (experimental)

Kiri is an **experimental HTTP server framework** that combines:

- a **Swift-first developer experience** (routing APIs, handlers, grouping)
- a **Rust/Tokio-based runtime** under the hood (networking, server loop)

The goal of the project is to explore how far a **hybrid Swift ↔ Rust architecture** can go while preserving:
- performance (Tokio + Hyper)
- safety (explicit ownership across FFI)
- a pleasant Swift API for application logic

> ⚠️ **Not for production use**
>
> This project is a **personal learning exercise**.
> It is **not audited**, **not hardened**, and **APIs / ABI are unstable**.
> Breaking changes are expected.

---

## What works today (MVP)

- Rust HTTP server using **Tokio + Hyper**
- Swift-defined routes and handler closures
- Route grouping on the Swift side (path prefixes)
- Cross-language request dispatch via FFI
- Binary request/response framing
- Cooperative cancellation (timeouts + client disconnect)
- Safe handling of late completions across FFI
- Graceful startup errors (e.g. port already in use)

---

## High-level architecture

### Request lifecycle

1. Swift creates a `Router` and registers routes.
2. Swift starts the server with a snapshot of the router.
3. Rust binds and starts serving HTTP requests.
4. Rust matches `(method, path)` against the route table.
5. Rust dispatches the request to Swift via `swift_dispatch`.
6. Swift executes the handler and completes via `kiri_request_complete`.
7. Rust writes the HTTP response.

### Router / Server separation

Kiri intentionally separates:
- **Router** (configuration phase)
- **Server** (serving phase)

Routes are registered *before* the server binds and are **snapshotted** at startup.
This avoids races while keeping route registration fast and deterministic.

---

## Swift ↔ Rust FFI model

- Rust owns all allocations exposed over FFI.
- Swift holds opaque pointers only.
- Shared request state is managed via `Arc`.
- Completion and cancellation are safe under:
  - timeouts
  - client disconnects
  - late Swift completions

---

## Cancellation model

Cancellation is **cooperative**, not automatic.

- Rust may cancel requests due to:
  - timeouts
  - client disconnects
- Swift handlers receive a cancellation handle and may:
  - check cancellation explicitly
  - stop early if appropriate

This keeps behavior predictable for side-effectful work
(e.g. database writes).

---

## Roadmap (short-term)

- [ ] Path parameters (`/users/:id`)
- [ ] Query parameters
- [ ] Headers
- [ ] Middleware
- [ ] Router performance optimizations (only if needed)

---

## License

TBD — this is currently a personal learning project.
