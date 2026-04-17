/// Minimum spanning forests for weighted undirected graphs.
extension Graph {

  /// Returns a minimum spanning forest containing every vertex.
  ///
  /// Each connected component is spanned independently, and isolated
  /// vertices are preserved. Edge weights may be negative. When multiple
  /// forests have the same total weight, any one may be returned.
  ///
  /// - Throws: ``GraphError/undirectedGraphRequired`` if the graph is directed.
  public func minimumSpanningForest() throws -> Graph<V> {
    guard !isDirected else {
      throw GraphError<V>.undirectedGraphRequired
    }

    var forest = Graph<V>(directed: false)
    for vertex in adjacencyMap.keys {
      try forest.addVertex(vertex)
    }

    var sets = DisjointSet(adjacencyMap.keys)
    for edge in allEdges().sorted(by: { $0.weight < $1.weight }) {
      if sets.union(edge.from, edge.to) {
        try forest.addEdge(from: edge.from, to: edge.to, weight: edge.weight)
      }
    }

    return forest
  }
}

private struct DisjointSet<Element: Hashable & Sendable>: Sendable {
  private var parent: [Element: Element]
  private var rank: [Element: Int]

  init<S: Sequence>(_ elements: S) where S.Element == Element {
    parent = Dictionary(uniqueKeysWithValues: elements.map { ($0, $0) })
    rank = Dictionary(uniqueKeysWithValues: elements.map { ($0, 0) })
  }

  mutating func union(_ first: Element, _ second: Element) -> Bool {
    let firstRoot = find(first)
    let secondRoot = find(second)
    guard firstRoot != secondRoot else {
      return false
    }

    let firstRank = rank[firstRoot, default: 0]
    let secondRank = rank[secondRoot, default: 0]
    if firstRank < secondRank {
      parent[firstRoot] = secondRoot
    } else if firstRank > secondRank {
      parent[secondRoot] = firstRoot
    } else {
      parent[secondRoot] = firstRoot
      rank[firstRoot] = firstRank + 1
    }
    return true
  }

  private mutating func find(_ element: Element) -> Element {
    var root = element
    while let next = parent[root], next != root {
      root = next
    }

    var current = element
    while let next = parent[current], next != current {
      parent[current] = root
      current = next
    }
    return root
  }
}
