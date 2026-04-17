/// Connectivity and cycle queries for graphs.
extension Graph {

  /// Returns the connected component containing `vertex` in an undirected graph.
  ///
  /// The order of returned vertices is not guaranteed.
  ///
  /// - Throws: ``GraphError/directedGraphRequired`` if the graph is directed,
  ///   or ``GraphError/missingVertex(_:)`` if `vertex` is not in the graph.
  public func connectedComponent(containing vertex: V) throws -> [V] {
    guard !isDirected else {
      throw GraphError<V>.directedGraphRequired
    }
    guard adjacencyMap[vertex] != nil else {
      throw GraphError.missingVertex(vertex)
    }

    var component = [vertex]
    var visited: Set<V> = [vertex]
    var nextIndex = 0

    while nextIndex < component.count {
      let current = component[nextIndex]
      nextIndex += 1
      for neighbor in try neighbors(of: current, direction: .outbound) {
        if visited.insert(neighbor).inserted {
          component.append(neighbor)
        }
      }
    }

    return component
  }

  /// Returns all connected components of an undirected graph.
  ///
  /// The order of components and of vertices within each component is not
  /// guaranteed. Isolated vertices are returned as single-vertex components.
  ///
  /// - Throws: ``GraphError/directedGraphRequired`` if the graph is directed.
  public func connectedComponents() throws -> [[V]] {
    guard !isDirected else {
      throw GraphError<V>.directedGraphRequired
    }
    return try components(direction: .outbound)
  }

  /// Returns the weakly connected components of a directed graph, treating
  /// every edge as bidirectional for connectivity purposes.
  ///
  /// The order of components and of vertices within each component is not
  /// guaranteed. Isolated vertices are returned as single-vertex components.
  ///
  /// - Throws: ``GraphError/undirectedGraphRequired`` if the graph is undirected.
  public func weaklyConnectedComponents() throws -> [[V]] {
    guard isDirected else {
      throw GraphError<V>.undirectedGraphRequired
    }
    return try components(direction: .noDirection)
  }

  /// Returns the strongly connected components of a directed graph.
  ///
  /// The order of components and of vertices within each component is not
  /// guaranteed. Isolated vertices are returned as single-vertex components.
  ///
  /// - Throws: ``GraphError/undirectedGraphRequired`` if the graph is undirected.
  public func stronglyConnectedComponents() throws -> [[V]] {
    guard isDirected else {
      throw GraphError<V>.undirectedGraphRequired
    }

    var visited: Set<V> = []
    var finishOrder: [V] = []

    for start in adjacencyMap.keys where visited.insert(start).inserted {
      var stack: [(vertex: V, neighbors: [V], nextIndex: Int)] = [
        (start, try neighbors(of: start, direction: .outbound), 0)
      ]

      while var frame = stack.popLast() {
        if frame.nextIndex == frame.neighbors.count {
          finishOrder.append(frame.vertex)
          continue
        }

        let next = frame.neighbors[frame.nextIndex]
        frame.nextIndex += 1
        stack.append(frame)

        if visited.insert(next).inserted {
          stack.append((next, try neighbors(of: next, direction: .outbound), 0))
        }
      }
    }

    visited.removeAll(keepingCapacity: true)
    var result: [[V]] = []

    for start in finishOrder.reversed() where visited.insert(start).inserted {
      var component = [start]
      var nextIndex = 0

      while nextIndex < component.count {
        let current = component[nextIndex]
        nextIndex += 1
        for neighbor in try neighbors(of: current, direction: .inbound) {
          if visited.insert(neighbor).inserted {
            component.append(neighbor)
          }
        }
      }

      result.append(component)
    }

    return result
  }

  /// Returns whether the graph contains a cycle.
  ///
  /// Directed graphs are checked using their in-degrees; undirected graphs
  /// are checked by tracking each traversal's parent vertex.
  public func hasCycle() -> Bool {
    isDirected ? hasDirectedCycle() : hasUndirectedCycle()
  }

  private func components(direction: Direction) throws -> [[V]] {
    var visited: Set<V> = []
    var result: [[V]] = []

    for start in adjacencyMap.keys where visited.insert(start).inserted {
      var component = [start]
      var nextIndex = 0

      while nextIndex < component.count {
        let current = component[nextIndex]
        nextIndex += 1
        for neighbor in try neighbors(of: current, direction: direction) {
          if visited.insert(neighbor).inserted {
            component.append(neighbor)
          }
        }
      }

      result.append(component)
    }

    return result
  }

  private func hasDirectedCycle() -> Bool {
    var inDegrees = adjacencyMap.mapValues { $0.implicit.count }
    var queue = inDegrees.compactMap { vertex, degree in
      degree == 0 ? vertex : nil
    }
    var nextIndex = 0
    var visitedCount = 0

    while nextIndex < queue.count {
      let vertex = queue[nextIndex]
      nextIndex += 1
      visitedCount += 1

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

    return visitedCount != vertexCount
  }

  private func hasUndirectedCycle() -> Bool {
    var visited: Set<V> = []
    var parentEdges: Set<EdgePair<V>> = []

    for start in adjacencyMap.keys where visited.insert(start).inserted {
      var stack = [start]

      while let vertex = stack.popLast() {
        guard let entry = adjacencyMap[vertex] else {
          continue
        }
        for neighbor in entry.explicit.keys {
          if visited.insert(neighbor).inserted {
            parentEdges.insert(EdgePair(a: vertex, b: neighbor))
            stack.append(neighbor)
          } else if !parentEdges.contains(EdgePair(a: vertex, b: neighbor)) {
            return true
          }
        }
      }
    }

    return false
  }
}
