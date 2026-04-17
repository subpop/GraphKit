/// Errors that can occur during graph operations.
public enum GraphError<V: Hashable & Sendable>: Error, Equatable, Sendable {
  /// The specified vertex does not exist in the graph.
  case missingVertex(V)

  /// The specified edge does not exist in the graph.
  case missingEdge(from: V, to: V)

  /// A vertex with the same value already exists in the graph.
  case duplicateVertex(V)

  /// An edge between the specified vertices already exists in the graph.
  case duplicateEdge(from: V, to: V)

  /// The operation requires a directed graph but was called on an undirected
  /// graph.
  case directedGraphRequired

  /// The operation requires an undirected graph but was called on a directed
  /// graph.
  case undirectedGraphRequired

  /// The minimum neighborhood distance is negative or greater than the
  /// maximum distance.
  case invalidDistanceRange(minimum: Int, maximum: Int)

  /// A shortest-path query encountered a negative-weight edge.
  case negativeEdgeWeight(from: V, to: V)

  /// A shortest-path query encountered a negative cycle.
  case negativeCycle
}
