import Testing
@testable import Kiri

@Suite("Path.join")
struct PathJoinTests {
  @Test("root + root")
  func rootRoot() {
    #expect(Path.join("", "") == "/")
    #expect(Path.join("/", "/") == "/")
    #expect(Path.join("///", "///") == "/")
  }

  @Test("root + leaf")
  func rootLeaf() {
    #expect(Path.join("", "ok") == "/ok")
    #expect(Path.join("", "/ok") == "/ok")
    #expect(Path.join("/", "ok") == "/ok")
    #expect(Path.join("/", "/ok") == "/ok")
  }

  @Test("base + empty leaf")
  func baseEmptyLeaf() {
    #expect(Path.join("api", "") == "/api")
    #expect(Path.join("/api", "") == "/api")
    #expect(Path.join("api/", "/") == "/api")
  }

  @Test("base + leaf")
  func baseAndLeaf() {
    #expect(Path.join("api", "users") == "/api/users")
    #expect(Path.join("/api", "users") == "/api/users")
    #expect(Path.join("api", "/users") == "/api/users")
     #expect(Path.join("/api/", "/users/") == "/api/users")
  }

  @Test("nested join (group inside group)")
  func nestedJoin() {
    let api = Path.join("api", "")
    #expect(api == "/api")

    let users = Path.join(api, "users")
    #expect(users == "/api/users")

    let userId = Path.join(users, ":id")
    #expect(userId == "/api/users/:id")
  }

  @Test("idempotency")
  func idempotency() {
    #expect(Path.join("", "/api/users") == "/api/users")
    #expect(Path.join("", Path.join("api", "users")) == "/api/users")
    #expect(Path.join(Path.join("api", "users"), "") == "/api/users")
  }

  @Test("weird but valid segments")
  func weirdSegments() {
    #expect(Path.join("api", "users:search") == "/api/users:search")
    #expect(Path.join("api", "users/:id") == "/api/users/:id")
    #expect(Path.join("api", "/users/:id/") == "/api/users/:id")
  }

  @Test("output invariants")
  func invariants() {
    let samples = [
      ("", "ok"),
      ("/", "/ok"),
      ("api", "users"),
      ("/api/", "/users/"),
      ("api/users", ":id"),
    ]

    for (a, b) in samples {
      let result = Path.join(a, b)
      #expect(result.hasPrefix("/"))
      #expect(!result.contains("//"))
    }
  }
}
