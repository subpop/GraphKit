/// A path and its total weight returned by a shortest-path algorithm.
public struct ShortestPathResult<Vertex: Hashable & Sendable>: Equatable, Sendable {
  /// The sum of the edge weights along the path, or infinity if unreachable.
  public let distance: Double

  /// The path, including its source and destination, or `nil` if unreachable.
  public let path: [Vertex]?
}

/// Weighted shortest-path algorithms and queries.
extension Graph {

  /// Returns minimum-weight paths from `source` to every vertex using Dijkstra's algorithm.
  ///
  /// Unreachable vertices have an infinite distance and a `nil` path.
  ///
  /// - Throws: ``GraphError/missingVertex(_:)`` if `source` is absent, or
  ///   ``GraphError/negativeEdgeWeight(from:to:)`` if the graph contains a
  ///   negative-weight edge.
  public func dijkstra(from source: V) throws -> [V: ShortestPathResult<V>] {
    guard adjacencyMap[source] != nil else {
      throw GraphError.missingVertex(source)
    }
    let paths = try shortestPaths(from: source)
    return Dictionary(
      uniqueKeysWithValues: adjacencyMap.keys.map { vertex in
        let distance = paths.distances[vertex] ?? .infinity
        return (
          vertex,
          ShortestPathResult(
            distance: distance,
            path: paths.distances[vertex] == nil
              ? nil
              : reconstructPath(from: source, to: vertex, predecessors: paths.predecessors)
          )
        )
      })
  }

  /// Returns minimum-weight paths from `source` using Bellman–Ford.
  ///
  /// Negative edge weights are supported. Unreachable vertices have an
  /// infinite distance and a `nil` path.
  ///
  /// - Throws: ``GraphError/missingVertex(_:)`` if `source` is absent, or
  ///   ``GraphError/negativeCycle`` if a negative cycle is reachable from it.
  public func bellmanFord(from source: V) throws -> [V: ShortestPathResult<V>] {
    guard adjacencyMap[source] != nil else {
      throw GraphError.missingVertex(source)
    }

    var distances = Dictionary(
      uniqueKeysWithValues: adjacencyMap.keys.map { ($0, Double.infinity) })
    var predecessors: [V: V] = [:]
    distances[source] = 0

    if vertexCount > 1 {
      for _ in 1..<vertexCount {
        var changed = false
        for edge in allEdges() {
          let sourceDistance = distances[edge.from, default: .infinity]
          guard sourceDistance != .infinity else { continue }
          let candidate = sourceDistance + edge.weight
          if candidate < distances[edge.to, default: .infinity] {
            distances[edge.to] = candidate
            predecessors[edge.to] = edge.from
            changed = true
          }
        }
        if !changed { break }
      }
    }

    for edge in allEdges() {
      let sourceDistance = distances[edge.from, default: .infinity]
      if sourceDistance != .infinity
        && sourceDistance + edge.weight < distances[edge.to, default: .infinity]
      {
        throw GraphError<V>.negativeCycle
      }
    }

    return Dictionary(
      uniqueKeysWithValues: adjacencyMap.keys.map { vertex in
        (
          vertex,
          ShortestPathResult(
            distance: distances[vertex, default: .infinity],
            path: distances[vertex] == .infinity
              ? nil
              : reconstructPath(from: source, to: vertex, predecessors: predecessors)
          )
        )
      })
  }

  /// Returns minimum-weight paths between every pair of vertices using Floyd–Warshall.
  ///
  /// Negative edge weights are supported. Unreachable pairs have an infinite
  /// distance and a `nil` path.
  ///
  /// - Throws: ``GraphError/negativeCycle`` if the graph contains a negative cycle.
  public func floydWarshall() throws -> [V: [V: ShortestPathResult<V>]] {
    let vertices = Array(adjacencyMap.keys)
    var distances = Dictionary(
      uniqueKeysWithValues: vertices.map { source in
        (
          source,
          Dictionary(
            uniqueKeysWithValues: vertices.map { destination in
              (destination, source == destination ? 0.0 : .infinity)
            })
        )
      })
    var next: [V: [V: V]] = [:]

    for edge in allEdges() where edge.weight < distances[edge.from]![edge.to]! {
      distances[edge.from]![edge.to] = edge.weight
      next[edge.from, default: [:]][edge.to] = edge.to
    }

    for intermediate in vertices {
      for source in vertices {
        let firstLeg = distances[source]![intermediate]!
        guard firstLeg != .infinity else { continue }
        for destination in vertices {
          let secondLeg = distances[intermediate]![destination]!
          guard secondLeg != .infinity else { continue }
          let candidate = firstLeg + secondLeg
          if candidate < distances[source]![destination]! {
            distances[source]![destination] = candidate
            next[source, default: [:]][destination] = next[source]?[intermediate]
          }
        }
      }
    }

    if vertices.contains(where: { distances[$0]![$0]! < 0 }) {
      throw GraphError<V>.negativeCycle
    }

    return Dictionary(
      uniqueKeysWithValues: vertices.map { source in
        (
          source,
          Dictionary(
            uniqueKeysWithValues: vertices.map { destination in
              (
                destination,
                ShortestPathResult(
                  distance: distances[source]![destination]!,
                  path: floydPath(from: source, to: destination, next: next, limit: vertices.count)
                )
              )
            })
        )
      })
  }

  /// Returns a minimum-weight path from `source` to `destination` using A*.
  ///
  /// The heuristic must be admissible (never overestimate the remaining
  /// distance) for the result to be optimal. Unreachable destinations have
  /// an infinite distance and a `nil` path.
  ///
  /// - Throws: ``GraphError/missingVertex(_:)`` if either endpoint is absent,
  ///   or ``GraphError/negativeEdgeWeight(from:to:)`` if the graph contains a
  ///   negative-weight edge.
  public func aStar(
    from source: V,
    to destination: V,
    heuristic: @Sendable (V) -> Double
  ) throws -> ShortestPathResult<V> {
    try validateShortestPathEndpoints(source, destination)
    try validateNonnegativeWeights()

    var distances: [V: Double] = [source: 0]
    var estimates: [V: Double] = [source: heuristic(source)]
    var predecessors: [V: V] = [:]
    var frontier: Set<V> = [source]

    while let current = frontier.min(by: {
      estimates[$0, default: .infinity] < estimates[$1, default: .infinity]
    }) {
      frontier.remove(current)
      if current == destination {
        return ShortestPathResult(
          distance: distances[current]!,
          path: reconstructPath(from: source, to: destination, predecessors: predecessors)
        )
      }

      for (neighbor, weight) in adjacencyMap[current]!.explicit {
        let candidate = distances[current]! + weight
        if candidate < distances[neighbor, default: .infinity] {
          distances[neighbor] = candidate
          predecessors[neighbor] = current
          estimates[neighbor] = candidate + heuristic(neighbor)
          frontier.insert(neighbor)
        }
      }
    }

    return ShortestPathResult(distance: .infinity, path: nil)
  }

  /// Returns minimum-hop paths from `source` using breadth-first search.
  ///
  /// Edge weights are ignored and every edge is treated as having weight 1.
  /// Unreachable vertices have an infinite distance and a `nil` path.
  ///
  /// - Throws: ``GraphError/missingVertex(_:)`` if `source` is absent.
  public func breadthFirstShortestPaths(from source: V) throws -> [V: ShortestPathResult<V>] {
    guard adjacencyMap[source] != nil else {
      throw GraphError.missingVertex(source)
    }

    var distances = Dictionary(
      uniqueKeysWithValues: adjacencyMap.keys.map { ($0, Double.infinity) })
    var predecessors: [V: V] = [:]
    var queue = [source]
    var nextIndex = 0
    distances[source] = 0

    while nextIndex < queue.count {
      let current = queue[nextIndex]
      nextIndex += 1
      for neighbor in adjacencyMap[current]!.explicit.keys where distances[neighbor] == .infinity {
        distances[neighbor] = distances[current]! + 1
        predecessors[neighbor] = current
        queue.append(neighbor)
      }
    }

    return Dictionary(
      uniqueKeysWithValues: adjacencyMap.keys.map { vertex in
        (
          vertex,
          ShortestPathResult(
            distance: distances[vertex, default: .infinity],
            path: distances[vertex] == .infinity
              ? nil
              : reconstructPath(from: source, to: vertex, predecessors: predecessors)
          )
        )
      })
  }

  /// Returns a minimum-weight path from `source` to `destination`.
  ///
  /// Returns `nil` when `destination` is unreachable. If several paths have
  /// the same weight, any one of them may be returned.
  ///
  /// - Throws: ``GraphError/missingVertex(_:)`` if either endpoint is absent,
  ///   or ``GraphError/negativeEdgeWeight(from:to:)`` if the graph contains a
  ///   negative-weight edge.
  public func shortestPath(from source: V, to destination: V) throws -> [V]? {
    try validateShortestPathEndpoints(source, destination)
    let result = try shortestPaths(from: source)
    guard result.distances[destination] != nil else {
      return nil
    }
    return reconstructPath(from: source, to: destination, predecessors: result.predecessors)
  }

  /// Returns the minimum total edge weight from `source` to `destination`.
  ///
  /// Returns `nil` when `destination` is unreachable.
  ///
  /// - Throws: ``GraphError/missingVertex(_:)`` if either endpoint is absent,
  ///   or ``GraphError/negativeEdgeWeight(from:to:)`` if the graph contains a
  ///   negative-weight edge.
  public func shortestDistance(from source: V, to destination: V) throws -> Double? {
    try validateShortestPathEndpoints(source, destination)
    return try shortestPaths(from: source).distances[destination]
  }

  private func validateShortestPathEndpoints(_ source: V, _ destination: V) throws {
    guard adjacencyMap[source] != nil else {
      throw GraphError.missingVertex(source)
    }
    guard adjacencyMap[destination] != nil else {
      throw GraphError.missingVertex(destination)
    }
  }

  private func validateNonnegativeWeights() throws {
    for edge in allEdges() where edge.weight < 0 {
      throw GraphError.negativeEdgeWeight(from: edge.from, to: edge.to)
    }
  }

  private func shortestPaths(from source: V) throws -> (
    distances: [V: Double], predecessors: [V: V]
  ) {
    try validateNonnegativeWeights()

    var distances: [V: Double] = [source: 0]
    var predecessors: [V: V] = [:]
    var unvisited = Set(adjacencyMap.keys)

    while let (current, distance) = unvisited.compactMap({ vertex in
      distances[vertex].map { (vertex, $0) }
    }).min(by: { $0.1 < $1.1 }) {
      unvisited.remove(current)
      for (neighbor, weight) in adjacencyMap[current]!.explicit where unvisited.contains(neighbor) {
        let candidate = distance + weight
        if candidate < distances[neighbor, default: .infinity] {
          distances[neighbor] = candidate
          predecessors[neighbor] = current
        }
      }
    }

    return (distances, predecessors)
  }

  private func reconstructPath(from source: V, to destination: V, predecessors: [V: V]) -> [V]? {
    if source == destination { return [source] }
    var path = [destination]
    var current = destination
    while current != source {
      guard let predecessor = predecessors[current] else { return nil }
      path.append(predecessor)
      current = predecessor
    }
    return path.reversed()
  }

  private func floydPath(from source: V, to destination: V, next: [V: [V: V]], limit: Int) -> [V]? {
    if source == destination { return [source] }
    guard next[source]?[destination] != nil else { return nil }

    var path = [source]
    var current = source
    for _ in 0..<limit {
      guard let successor = next[current]?[destination] else { return nil }
      current = successor
      path.append(current)
      if current == destination { return path }
    }
    return nil
  }
}
