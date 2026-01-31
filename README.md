# Kiri (experimental)

Kiri is an experimental HTTP server framework that aims to combine:

- a **Swift-first developer experience** (routing APIs, handlers, etc.)
- a **Rust/Tokio-based runtime** under the hood (server loop, networking)

This project exists primarily as a **learning exercise** to explore:
- Swift ↔ Rust interoperability (FFI)
- request routing across language boundaries
- memory ownership and lifecycle across FFI
- cooperative cancellation and timeouts

> ⚠️ **Not for production use.**
> This codebase is **not audited**, **not hardened**, and APIs/ABI may change at any time.
> It’s currently meant only for **my learning purposes** and experimentation.

---

## What works today (MVP)

- Start/stop an HTTP server implemented in Rust (Tokio + Hyper).
- Register Swift routes (e.g. `GET /hello`) with handler closures.
- Route requests in Rust and dispatch to Swift handlers via FFI.
- Return responses back to Rust via a binary frame protocol.
- Hard-coded request timeout (currently **5 seconds**).
- Cooperative cancellation primitives exposed to Swift (opt-in checks).

---

## Architecture overview

### Request/response flow

1. Swift registers routes and handlers.
2. Rust accepts incoming HTTP requests.
3. Rust matches `(method, path)` against registered routes.
4. Rust calls into Swift (`swift_dispatch`) with an encoded request frame.
5. Swift runs the handler and returns an encoded response frame via `rust_complete`.
6. Rust decodes the response frame and writes the HTTP response.

### FFI and ownership

This project uses an **opaque handle** pattern over FFI:
- Swift never dereferences Rust pointers.
- Rust controls allocation/freeing.
- Completion and cancellation are implemented using `Arc`-managed shared state to remain safe under timeouts and late completions.

---

## Cancellation model (important)

Cancellation is **cooperative** (opt-in), not automatic:

- Rust may cancel a request due to timeout (and soon: client disconnect).
- Swift handlers can check a `CancellationToken` and decide whether to stop early.
- This keeps behavior predictable (e.g. handlers doing database work can decide whether to rollback/commit safely).

---

## Status and roadmap

Immediate focus:
- **Client disconnect cancellation** (in addition to timeout cancellation)

Planned improvements:
- [ ] Better error handling and startup failures (e.g. port already in use)
- [ ] Path params extraction (`/users/:id`)
- [ ] Headers, query params
- [ ] Middleware
- [ ] Better router performance (only when needed)

---

## Building and running

This repository contains:
- a Rust library (Tokio/Hyper server runtime + FFI exports)
- a Swift Package that links the Rust library and exposes Swift APIs

The exact build steps may evolve; at a high level the workflow is:

1. Build the Rust library (`cargo build`)
2. Make the produced static lib available to SwiftPM (copy or configure search paths)
3. Build/run the Swift executable that starts the server

If you’re working on this repo, check the scripts or package configuration used in the current branch (this is still evolving).

---

## License

TBD (this is currently a personal learning project).
