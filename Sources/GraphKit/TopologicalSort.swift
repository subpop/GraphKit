/// Topological ordering for directed acyclic graphs.
extension Graph {

  /// Returns a topological ordering of the graph's vertices.
  ///
  /// Returns `nil` when the graph contains a cycle. The order among vertices
  /// that are not constrained by an edge is not guaranteed.
  ///
  /// - Throws: ``GraphError/undirectedGraphRequired`` if the graph is
  ///   undirected.
  public func topologicalSort() throws -> [V]? {
    guard isDirected else {
      throw GraphError<V>.undirectedGraphRequired
    }

    var inDegrees = adjacencyMap.mapValues { $0.implicit.count }
    var queue = inDegrees.compactMap { vertex, degree in
      degree == 0 ? vertex : nil
    }
    var order: [V] = []
    var nextIndex = 0

    while nextIndex < queue.count {
      let vertex = queue[nextIndex]
      nextIndex += 1
      order.append(vertex)

      guard let entry = adjacencyMap[vertex] else {
        continue
      }
      for neighbor in entry.explicit.keys {
        inDegrees[neighbor, default: 0] -= 1
        if inDegrees[neighbor] == 0 {
          queue.append(neighbor)
        }
      }
    }

    return order.count == vertexCount ? order : nil
  }
}
