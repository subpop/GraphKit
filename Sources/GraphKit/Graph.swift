/// A weighted graph data structure that supports both directed and undirected
/// edges.
///
/// `Graph` stores vertices of any `Hashable` type and weighted edges between
/// them. Edge weights are `Double` values, defaulting to `0.0` when not
/// specified.
///
/// Internally, each vertex maintains two edge maps:
/// - **Explicit edges** are the forward (user-created) edges.
/// - **Implicit edges** are automatically-maintained reverse edges used in
///   directed graphs to enable efficient inbound neighbor queries.
///
/// In undirected graphs, both directions of an edge are stored as explicit
/// edges. In directed graphs, only the forward direction is explicit; the
/// reverse is implicit.
///
/// ## Example
///
/// ```swift
/// var g = Graph<String>(directed: true)
/// try g.addEdge(from: "A", to: "B", weight: 4.0)
/// try g.addEdge(from: "A", to: "C", weight: 2.0)
/// print(g.vertexCount) // 3
/// print(g.edgeCount)   // 2
/// ```
public struct Graph<V: Hashable & Sendable> {

  // MARK: - Internal Storage

  /// Maps each vertex to its adjacency entry containing explicit (forward)
  /// and implicit (reverse) edge maps.
  var adjacencyMap: [V: AdjacencyEntry]

  /// Whether this graph treats edges as directed.
  public let isDirected: Bool

  /// The adjacency entry for a single vertex, containing explicit (forward)
  /// and implicit (reverse) edge maps.
  struct AdjacencyEntry {
    /// Edges explicitly created by the user. In undirected graphs, both
    /// directions are stored here.
    var explicit: [V: Double] = [:]

    /// Reverse edges automatically maintained for directed graphs, enabling
    /// efficient inbound neighbor lookups. Always empty for undirected
    /// graphs.
    var implicit: [V: Double] = [:]
  }

  // MARK: - Initialization

  /// Creates a new empty graph.
  ///
  /// - Parameter directed: If `true`, the graph treats edges as directed
  ///   (from source to destination). If `false`, edges are bidirectional.
  public init(directed: Bool) {
    self.isDirected = directed
    self.adjacencyMap = [:]
  }

  // MARK: - Vertex Operations

  /// Adds a vertex to the graph.
  ///
  /// - Parameter v: The vertex to add.
  /// - Throws: ``GraphError/duplicateVertex(_:)`` if the vertex already
  ///   exists.
  public mutating func addVertex(_ v: V) throws {
    guard adjacencyMap[v] == nil else {
      throw GraphError.duplicateVertex(v)
    }
    adjacencyMap[v] = AdjacencyEntry()
  }

  /// Adds multiple vertices to the graph.
  ///
  /// All vertices are added in order. If a duplicate is encountered, the
  /// operation stops and throws, but previously added vertices in this call
  /// remain in the graph.
  ///
  /// - Parameter vertices: The vertices to add.
  /// - Throws: ``GraphError/duplicateVertex(_:)`` if any vertex already
  ///   exists.
  public mutating func addVertices(_ vertices: V...) throws {
    for v in vertices {
      try addVertex(v)
    }
  }

  /// Removes a vertex and all of its edges from the graph.
  ///
  /// - Parameter v: The vertex to remove.
  /// - Throws: ``GraphError/missingVertex(_:)`` if the vertex does not exist.
  public mutating func removeVertex(_ v: V) throws {
    guard let entry = adjacencyMap[v] else {
      throw GraphError.missingVertex(v)
    }

    // Remove edges pointing to this vertex from other vertices.
    if isDirected {
      // Use explicit edges to find outbound neighbors and remove their
      // implicit entries.
      for neighbor in entry.explicit.keys {
        adjacencyMap[neighbor]?.implicit.removeValue(forKey: v)
      }
      // Use implicit edges to find inbound neighbors and remove their
      // explicit entries.
      for neighbor in entry.implicit.keys {
        adjacencyMap[neighbor]?.explicit.removeValue(forKey: v)
      }
    } else {
      // In undirected graphs, all edges are explicit in both directions.
      for neighbor in entry.explicit.keys {
        adjacencyMap[neighbor]?.explicit.removeValue(forKey: v)
      }
    }

    adjacencyMap.removeValue(forKey: v)
  }

  // MARK: - Edge Operations

  /// Adds a weighted edge between two vertices.
  ///
  /// If either vertex does not exist in the graph, it is automatically
  /// created.
  ///
  /// - Parameters:
  ///   - a: The source vertex.
  ///   - b: The destination vertex.
  ///   - weight: The edge weight. Defaults to `0.0`.
  /// - Throws: ``GraphError/duplicateEdge(from:to:)`` if the edge already
  ///   exists.
  public mutating func addEdge(from a: V, to b: V, weight: Double = 0.0) throws {
    // Ensure both vertices exist (auto-create if missing).
    if adjacencyMap[a] == nil {
      adjacencyMap[a] = AdjacencyEntry()
    }
    if adjacencyMap[b] == nil {
      adjacencyMap[b] = AdjacencyEntry()
    }

    // Check for duplicate edge.
    if adjacencyMap[a]!.explicit[b] != nil {
      throw GraphError.duplicateEdge(from: a, to: b)
    }

    if isDirected {
      adjacencyMap[a]!.explicit[b] = weight
      adjacencyMap[b]!.implicit[a] = weight
    } else {
      adjacencyMap[a]!.explicit[b] = weight
      adjacencyMap[b]!.explicit[a] = weight
    }
  }

  /// Removes the edge between two vertices.
  ///
  /// - Parameters:
  ///   - a: The source vertex.
  ///   - b: The destination vertex.
  /// - Throws: ``GraphError/missingVertex(_:)`` if either vertex does not
  ///   exist, or ``GraphError/missingEdge(from:to:)`` if the edge does not
  ///   exist.
  public mutating func removeEdge(from a: V, to b: V) throws {
    guard adjacencyMap[a] != nil else {
      throw GraphError.missingVertex(a)
    }
    guard adjacencyMap[b] != nil else {
      throw GraphError.missingVertex(b)
    }
    guard adjacencyMap[a]!.explicit[b] != nil else {
      throw GraphError.missingEdge(from: a, to: b)
    }

    if isDirected {
      adjacencyMap[a]!.explicit.removeValue(forKey: b)
      adjacencyMap[b]!.implicit.removeValue(forKey: a)
    } else {
      adjacencyMap[a]!.explicit.removeValue(forKey: b)
      adjacencyMap[b]!.explicit.removeValue(forKey: a)
    }
  }

  // MARK: - Query Operations

  /// The number of vertices in the graph.
  public var vertexCount: Int {
    adjacencyMap.count
  }

  /// The number of edges in the graph.
  ///
  /// For undirected graphs, each edge is counted once (not twice).
  public var edgeCount: Int {
    let totalExplicit = adjacencyMap.values.reduce(0) { $0 + $1.explicit.count }
    if isDirected {
      return totalExplicit
    }
    // In undirected graphs, each edge is stored twice (once per endpoint).
    return totalExplicit / 2
  }

  /// Returns the neighbors of a vertex for the given direction.
  ///
  /// - Parameters:
  ///   - v: The vertex to query.
  ///   - direction: The direction of edges to consider. For undirected graphs
  ///     all directions return the same result.
  /// - Returns: An array of neighboring vertices.
  /// - Throws: ``GraphError/missingVertex(_:)`` if the vertex does not exist.
  public func neighbors(of v: V, direction: Direction = .noDirection) throws -> [V] {
    guard let entry = adjacencyMap[v] else {
      throw GraphError.missingVertex(v)
    }

    if !isDirected {
      // Undirected: all neighbors are in the explicit map.
      return Array(entry.explicit.keys)
    }

    switch direction {
    case .outbound:
      return Array(entry.explicit.keys)
    case .inbound:
      return Array(entry.implicit.keys)
    case .noDirection:
      // Combine outbound and inbound, avoiding duplicates.
      var result = Set(entry.explicit.keys)
      result.formUnion(entry.implicit.keys)
      return Array(result)
    }
  }

  /// Returns whether the graph contains the given vertex.
  ///
  /// - Parameter v: The vertex to check.
  /// - Returns: `true` if the vertex exists in the graph.
  public func hasVertex(_ v: V) -> Bool {
    adjacencyMap[v] != nil
  }

  /// Returns whether an edge exists between two vertices.
  ///
  /// - Parameters:
  ///   - a: The source vertex.
  ///   - b: The destination vertex.
  /// - Returns: `true` if the edge exists.
  public func hasEdge(from a: V, to b: V) -> Bool {
    adjacencyMap[a]?.explicit[b] != nil
  }

  /// Returns the weight of the edge between two vertices.
  ///
  /// - Parameters:
  ///   - a: The source vertex.
  ///   - b: The destination vertex.
  /// - Returns: The edge weight.
  /// - Throws: ``GraphError/missingVertex(_:)`` if either vertex does not
  ///   exist, or ``GraphError/missingEdge(from:to:)`` if the edge does not
  ///   exist.
  public func edgeWeight(from a: V, to b: V) throws -> Double {
    guard adjacencyMap[a] != nil else {
      throw GraphError.missingVertex(a)
    }
    guard adjacencyMap[b] != nil else {
      throw GraphError.missingVertex(b)
    }
    guard let weight = adjacencyMap[a]!.explicit[b] else {
      throw GraphError.missingEdge(from: a, to: b)
    }
    return weight
  }

  /// Returns all vertices in the graph.
  ///
  /// The order of vertices is not guaranteed.
  public func allVertices() -> [V] {
    Array(adjacencyMap.keys)
  }

  /// Returns all edges in the graph.
  ///
  /// For undirected graphs, each edge is returned once. The order of edges
  /// is not guaranteed.
  ///
  /// - Returns: An array of tuples containing the source vertex, destination
  ///   vertex, and edge weight.
  public func allEdges() -> [(from: V, to: V, weight: Double)] {
    var edges: [(from: V, to: V, weight: Double)] = []

    if isDirected {
      for (vertex, entry) in adjacencyMap {
        for (neighbor, weight) in entry.explicit {
          edges.append((from: vertex, to: neighbor, weight: weight))
        }
      }
    } else {
      // For undirected graphs, deduplicate by only including each edge
      // once. We track which edges we've already added.
      var seen: Set<EdgePair<V>> = []
      for (vertex, entry) in adjacencyMap {
        for (neighbor, weight) in entry.explicit {
          let pair = EdgePair(a: vertex, b: neighbor)
          if seen.insert(pair).inserted {
            edges.append((from: vertex, to: neighbor, weight: weight))
          }
        }
      }
    }

    return edges
  }

  /// Returns the degree of a vertex in an undirected graph.
  ///
  /// The degree is the number of edges incident to the vertex.
  ///
  /// - Parameter v: The vertex to query.
  /// - Returns: The degree of the vertex.
  /// - Throws: ``GraphError/undirectedGraphRequired`` if the graph is
  ///   directed, or ``GraphError/missingVertex(_:)`` if the vertex does not
  ///   exist.
  public func degree(of v: V) throws -> Int {
    guard !isDirected else {
      throw GraphError<V>.undirectedGraphRequired
    }
    guard let entry = adjacencyMap[v] else {
      throw GraphError.missingVertex(v)
    }
    return entry.explicit.count
  }

  /// Returns the in-degree of a vertex in a directed graph.
  ///
  /// The in-degree is the number of edges pointing to the vertex.
  ///
  /// - Parameter v: The vertex to query.
  /// - Returns: The in-degree of the vertex.
  /// - Throws: ``GraphError/directedGraphRequired`` if the graph is
  ///   undirected, or ``GraphError/missingVertex(_:)`` if the vertex does not
  ///   exist.
  public func inDegree(of v: V) throws -> Int {
    guard isDirected else {
      throw GraphError<V>.directedGraphRequired
    }
    guard let entry = adjacencyMap[v] else {
      throw GraphError.missingVertex(v)
    }
    return entry.implicit.count
  }

  /// Returns the out-degree of a vertex in a directed graph.
  ///
  /// The out-degree is the number of edges originating from the vertex.
  ///
  /// - Parameter v: The vertex to query.
  /// - Returns: The out-degree of the vertex.
  /// - Throws: ``GraphError/directedGraphRequired`` if the graph is
  ///   undirected, or ``GraphError/missingVertex(_:)`` if the vertex does not
  ///   exist.
  public func outDegree(of v: V) throws -> Int {
    guard isDirected else {
      throw GraphError<V>.directedGraphRequired
    }
    guard let entry = adjacencyMap[v] else {
      throw GraphError.missingVertex(v)
    }
    return entry.explicit.count
  }
}

// MARK: - CustomStringConvertible

extension Graph: CustomStringConvertible {
  public var description: String {
    var lines: [String] = []
    for (vertex, entry) in adjacencyMap {
      for (neighbor, weight) in entry.explicit {
        lines.append("\(vertex) -(\(weight))-> \(neighbor)")
      }
    }
    if lines.isEmpty {
      return "Graph(vertices: \(vertexCount), edges: 0)"
    }
    return lines.joined(separator: "\n")
  }
}

// MARK: - Sendable

extension Graph: Sendable {}
extension Graph.AdjacencyEntry: Sendable {}

// MARK: - Internal Helpers

/// An unordered pair of vertices, used for deduplicating edges in undirected
/// graphs.
struct EdgePair<V: Hashable & Sendable>: Hashable, Sendable {
  let a: V
  let b: V

  func hash(into hasher: inout Hasher) {
    // Use an order-independent hash so that EdgePair(a, b) and
    // EdgePair(b, a) produce the same hash value.
    let hashA = a.hashValue
    let hashB = b.hashValue
    hasher.combine(hashA ^ hashB)
    hasher.combine(hashA &+ hashB)
  }

  static func == (lhs: EdgePair, rhs: EdgePair) -> Bool {
    (lhs.a == rhs.a && lhs.b == rhs.b) || (lhs.a == rhs.b && lhs.b == rhs.a)
  }
}
