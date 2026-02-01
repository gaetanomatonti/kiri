import Foundation

enum Path {
  static func join(_ base: String, _ leaf: String) -> String {
    let charactersToTrim = CharacterSet(charactersIn: "/")
    let base = base.trimmingCharacters(in: charactersToTrim)
    let leaf = leaf.trimmingCharacters(in: charactersToTrim)

    if base.isEmpty && leaf.isEmpty {
      return "/"
    }

    if base.isEmpty {
      return "/" + leaf
    }

    if leaf.isEmpty {
      return "/" + base
    }

    return "/" + base + "/" + leaf
  }
}
