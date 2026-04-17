/// Graph traversal and hop-distance queries.
extension Graph {

  /// Returns the vertices reachable from `start` in depth-first order.
  ///
  /// The order among neighboring vertices is not guaranteed.
  ///
  /// - Parameters:
  ///   - start: The vertex from which to begin traversal.
  ///   - direction: The edge direction to follow. Defaults to both inbound
  ///     and outbound edges.
  /// - Throws: ``GraphError/missingVertex(_:)`` if `start` is not in the graph.
  public func depthFirstSearch(
    from start: V,
    direction: Direction = .noDirection
  ) throws -> [V] {
    var result: [V] = []
    try depthFirstVisit(from: start, direction: direction) { vertex in
      result.append(vertex)
      return false
    }
    return result
  }

  /// Visits the vertices reachable from `start` in depth-first order.
  ///
  /// Returning `true` from `visitor` stops the traversal immediately. The
  /// order among neighboring vertices is not guaranteed.
  ///
  /// - Parameters:
  ///   - start: The vertex from which to begin traversal.
  ///   - direction: The edge direction to follow. Defaults to both inbound
  ///     and outbound edges.
  ///   - visitor: A closure called once for each visited vertex. Return `true`
  ///     to stop traversal.
  /// - Throws: ``GraphError/missingVertex(_:)`` if `start` is not in the graph.
  public func depthFirstVisit(
    from start: V,
    direction: Direction = .noDirection,
    visitor: (V) -> Bool
  ) throws {
    guard adjacencyMap[start] != nil else {
      throw GraphError.missingVertex(start)
    }

    var visited: Set<V> = [start]
    var stack = [start]

    while let vertex = stack.popLast() {
      if visitor(vertex) {
        return
      }

      for neighbor in try neighbors(of: vertex, direction: direction).reversed() {
        if visited.insert(neighbor).inserted {
          stack.append(neighbor)
        }
      }
    }
  }

  /// Returns the vertices reachable from `start` in breadth-first order.
  ///
  /// The order among vertices at the same distance is not guaranteed.
  ///
  /// - Parameters:
  ///   - start: The vertex from which to begin traversal.
  ///   - direction: The edge direction to follow. Defaults to both inbound
  ///     and outbound edges.
  /// - Throws: ``GraphError/missingVertex(_:)`` if `start` is not in the graph.
  public func breadthFirstSearch(
    from start: V,
    direction: Direction = .noDirection
  ) throws -> [V] {
    var result: [V] = []
    try breadthFirstVisit(from: start, direction: direction) { vertex in
      result.append(vertex)
      return false
    }
    return result
  }

  /// Visits the vertices reachable from `start` in breadth-first order.
  ///
  /// Returning `true` from `visitor` stops the traversal immediately. The
  /// order among vertices at the same distance is not guaranteed.
  ///
  /// - Parameters:
  ///   - start: The vertex from which to begin traversal.
  ///   - direction: The edge direction to follow. Defaults to both inbound
  ///     and outbound edges.
  ///   - visitor: A closure called once for each visited vertex. Return `true`
  ///     to stop traversal.
  /// - Throws: ``GraphError/missingVertex(_:)`` if `start` is not in the graph.
  public func breadthFirstVisit(
    from start: V,
    direction: Direction = .noDirection,
    visitor: (V) -> Bool
  ) throws {
    guard adjacencyMap[start] != nil else {
      throw GraphError.missingVertex(start)
    }

    var visited: Set<V> = [start]
    var queue = [start]
    var nextIndex = 0

    while nextIndex < queue.count {
      let vertex = queue[nextIndex]
      nextIndex += 1

      if visitor(vertex) {
        return
      }

      for neighbor in try neighbors(of: vertex, direction: direction) {
        if visited.insert(neighbor).inserted {
          queue.append(neighbor)
        }
      }
    }
  }

  /// Returns vertices whose shortest hop distance from `vertex` is within
  /// the specified range.
  ///
  /// `minimumDistance` defaults to zero, so the starting vertex is included
  /// by default. Vertices are returned in breadth-first order; ordering among
  /// vertices at the same distance is not guaranteed.
  ///
  /// - Parameters:
  ///   - vertex: The vertex from which to measure distances.
  ///   - maximumDistance: The greatest hop distance to include.
  ///   - minimumDistance: The least hop distance to include. Defaults to `0`.
  ///   - direction: The edge direction to follow. Defaults to both inbound
  ///     and outbound edges.
  /// - Throws: ``GraphError/invalidDistanceRange(minimum:maximum:)`` if the
  ///   range is negative or reversed, or ``GraphError/missingVertex(_:)`` if
  ///   `vertex` is not in the graph.
  public func neighborhood(
    of vertex: V,
    maximumDistance: Int,
    minimumDistance: Int = 0,
    direction: Direction = .noDirection
  ) throws -> [V] {
    guard minimumDistance >= 0, maximumDistance >= minimumDistance else {
      throw GraphError<V>.invalidDistanceRange(
        minimum: minimumDistance,
        maximum: maximumDistance
      )
    }
    guard adjacencyMap[vertex] != nil else {
      throw GraphError.missingVertex(vertex)
    }

    var result: [V] = []
    var visited: Set<V> = [vertex]
    var queue: [(vertex: V, distance: Int)] = [(vertex, 0)]
    var nextIndex = 0

    while nextIndex < queue.count {
      let (current, distance) = queue[nextIndex]
      nextIndex += 1

      if distance >= minimumDistance {
        result.append(current)
      }
      guard distance < maximumDistance else {
        continue
      }

      for neighbor in try neighbors(of: current, direction: direction) {
        if visited.insert(neighbor).inserted {
          queue.append((neighbor, distance + 1))
        }
      }
    }

    return result
  }
}
