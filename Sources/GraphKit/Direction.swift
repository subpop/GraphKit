public enum Direction: Sendable {
  /// Both inbound and outbound edges (or all edges for undirected graphs).
  case noDirection

  /// Only outgoing edges.
  case outbound

  /// Only incoming edges.
  case inbound
}
