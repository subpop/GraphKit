import Testing

@testable import GraphKit

enum SingleSourceAlgorithm: Sendable {
  case dijkstra
  case bellmanFord
  case breadthFirst
}

struct PathBatchExpectation: Sendable {
  let distances: [String: Double]
  let paths: [String: [[String]]]
}

struct SingleSourcePathCase: Sendable {
  let name: String
  let algorithm: SingleSourceAlgorithm
  let fixture: GraphFixture
  let source: String
  let expected: Result<PathBatchExpectation, GraphError<String>>
}

private func expectPaths(
  _ actual: [String: ShortestPathResult<String>],
  toMatch expected: PathBatchExpectation,
  named name: String
) {
  #expect(actual.count == expected.distances.count, Comment(rawValue: name))
  for (vertex, distance) in expected.distances {
    guard let result = actual[vertex] else {
      #expect(Bool(false), Comment(rawValue: "\(name): missing result for \(vertex)"))
      continue
    }
    #expect(result.distance == distance, Comment(rawValue: "\(name): distance to \(vertex)"))
    let paths = expected.paths[vertex, default: []]
    if paths.isEmpty {
      #expect(result.path == nil, Comment(rawValue: "\(name): path to \(vertex)"))
    } else {
      #expect(
        result.path.map { paths.contains($0) } == true,
        Comment(rawValue: "\(name): path to \(vertex)"))
    }
  }
}

@Suite("Single-Source Shortest Paths")
struct SingleSourceShortestPathTests {
  @Test(
    "Returns paths and distances or the algorithm-specific error",
    arguments: [
      SingleSourcePathCase(
        name: "Dijkstra picks minimum-weight paths and marks unreachable vertices",
        algorithm: .dijkstra,
        fixture: GraphFixture(
          directed: true,
          vertices: ["U"],
          edges: [
            TestEdge("A", "B", weight: 1), TestEdge("A", "C", weight: 1),
            TestEdge("B", "D", weight: 2), TestEdge("C", "D", weight: 2),
          ]
        ),
        source: "A",
        expected: .success(
          PathBatchExpectation(
            distances: ["A": 0, "B": 1, "C": 1, "D": 3, "U": .infinity],
            paths: [
              "A": [["A"]], "B": [["A", "B"]], "C": [["A", "C"]],
              "D": [["A", "B", "D"], ["A", "C", "D"]], "U": [],
            ]
          ))
      ),
      SingleSourcePathCase(
        name: "Dijkstra rejects negative edges",
        algorithm: .dijkstra,
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B", weight: -1)]),
        source: "A",
        expected: .failure(.negativeEdgeWeight(from: "A", to: "B"))
      ),
      SingleSourcePathCase(
        name: "Dijkstra reports a missing source",
        algorithm: .dijkstra,
        fixture: GraphFixture(directed: true),
        source: "A",
        expected: .failure(.missingVertex("A"))
      ),
      SingleSourcePathCase(
        name: "Bellman-Ford handles negative edges",
        algorithm: .bellmanFord,
        fixture: GraphFixture(
          directed: true,
          vertices: ["U"],
          edges: [
            TestEdge("A", "B", weight: 4), TestEdge("A", "C", weight: 5),
            TestEdge("C", "B", weight: -3), TestEdge("B", "D", weight: 2),
          ]
        ),
        source: "A",
        expected: .success(
          PathBatchExpectation(
            distances: ["A": 0, "B": 2, "C": 5, "D": 4, "U": .infinity],
            paths: [
              "A": [["A"]], "B": [["A", "C", "B"]], "C": [["A", "C"]], "D": [["A", "C", "B", "D"]],
              "U": [],
            ]
          ))
      ),
      SingleSourcePathCase(
        name: "Bellman-Ford detects a reachable negative cycle",
        algorithm: .bellmanFord,
        fixture: GraphFixture(
          directed: true,
          edges: [
            TestEdge("A", "B", weight: 1), TestEdge("B", "C", weight: -3),
            TestEdge("C", "A", weight: 1),
          ]
        ),
        source: "A",
        expected: .failure(.negativeCycle)
      ),
      SingleSourcePathCase(
        name: "Bellman-Ford reports a missing source",
        algorithm: .bellmanFord,
        fixture: GraphFixture(directed: true),
        source: "A",
        expected: .failure(.missingVertex("A"))
      ),
      SingleSourcePathCase(
        name: "Bellman-Ford ignores an unreachable negative cycle",
        algorithm: .bellmanFord,
        fixture: GraphFixture(
          directed: true,
          vertices: ["A"],
          edges: [TestEdge("B", "C", weight: -2), TestEdge("C", "B", weight: 1)]
        ),
        source: "A",
        expected: .success(
          PathBatchExpectation(
            distances: ["A": 0, "B": .infinity, "C": .infinity],
            paths: ["A": [["A"]], "B": [], "C": []]))
      ),
      SingleSourcePathCase(
        name: "BFS minimizes hops and ignores edge weights",
        algorithm: .breadthFirst,
        fixture: GraphFixture(
          directed: true,
          vertices: ["U"],
          edges: [
            TestEdge("A", "B", weight: 100), TestEdge("B", "D", weight: 100),
            TestEdge("A", "D", weight: 1000), TestEdge("A", "C", weight: 1),
            TestEdge("C", "D", weight: 1),
          ]
        ),
        source: "A",
        expected: .success(
          PathBatchExpectation(
            distances: ["A": 0, "B": 1, "C": 1, "D": 1, "U": .infinity],
            paths: [
              "A": [["A"]], "B": [["A", "B"]], "C": [["A", "C"]], "D": [["A", "D"]], "U": [],
            ]
          ))
      ),
      SingleSourcePathCase(
        name: "missing source is reported",
        algorithm: .breadthFirst,
        fixture: GraphFixture(directed: true),
        source: "A",
        expected: .failure(.missingVertex("A"))
      ),
    ])
  func singleSourceAlgorithms(_ testCase: SingleSourcePathCase) throws {
    let graph = try makeGraph(testCase.fixture)
    switch testCase.expected {
    case .success(let expected):
      let results: [String: ShortestPathResult<String>]
      switch testCase.algorithm {
      case .dijkstra:
        results = try graph.dijkstra(from: testCase.source)
      case .bellmanFord:
        results = try graph.bellmanFord(from: testCase.source)
      case .breadthFirst:
        results = try graph.breadthFirstShortestPaths(from: testCase.source)
      }
      expectPaths(results, toMatch: expected, named: testCase.name)
    case .failure(let error):
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        switch testCase.algorithm {
        case .dijkstra:
          try graph.dijkstra(from: testCase.source)
        case .bellmanFord:
          try graph.bellmanFord(from: testCase.source)
        case .breadthFirst:
          try graph.breadthFirstShortestPaths(from: testCase.source)
        }
      }
    }
  }
}

struct FloydWarshallCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let expectedDistances: [String: [String: Double]]
  let expectedPaths: [String: [String: [[String]]]]
  let expectedError: GraphError<String>?
}

@Suite("Floyd-Warshall")
struct FloydWarshallTests {
  @Test(
    "Returns all-pairs paths and detects negative cycles",
    arguments: [
      FloydWarshallCase(
        name: "combines positive and negative edges across disconnected vertices",
        fixture: GraphFixture(
          directed: true,
          vertices: ["D"],
          edges: [
            TestEdge("A", "B", weight: 4), TestEdge("A", "C", weight: 5),
            TestEdge("C", "B", weight: -3),
          ]
        ),
        expectedDistances: [
          "A": ["A": 0, "B": 2, "C": 5, "D": .infinity],
          "B": ["A": .infinity, "B": 0, "C": .infinity, "D": .infinity],
          "C": ["A": .infinity, "B": -3, "C": 0, "D": .infinity],
          "D": ["A": .infinity, "B": .infinity, "C": .infinity, "D": 0],
        ],
        expectedPaths: [
          "A": ["A": [["A"]], "B": [["A", "C", "B"]], "C": [["A", "C"]], "D": []],
          "B": ["A": [], "B": [["B"]], "C": [], "D": []],
          "C": ["A": [], "B": [["C", "B"]], "C": [["C"]], "D": []],
          "D": ["A": [], "B": [], "C": [], "D": [["D"]]],
        ],
        expectedError: nil
      ),
      FloydWarshallCase(
        name: "empty graph returns an empty matrix",
        fixture: GraphFixture(directed: true),
        expectedDistances: [:],
        expectedPaths: [:],
        expectedError: nil
      ),
      FloydWarshallCase(
        name: "reports a negative cycle",
        fixture: GraphFixture(
          directed: true, edges: [TestEdge("A", "B", weight: -2), TestEdge("B", "A", weight: 1)]),
        expectedDistances: [:],
        expectedPaths: [:],
        expectedError: .negativeCycle
      ),
    ])
  func allPairsPaths(_ testCase: FloydWarshallCase) throws {
    let graph = try makeGraph(testCase.fixture)
    if let error = testCase.expectedError {
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        try graph.floydWarshall()
      }
      return
    }

    let results = try graph.floydWarshall()
    #expect(results.count == testCase.expectedDistances.count, Comment(rawValue: testCase.name))
    for (source, destinations) in testCase.expectedDistances {
      for (destination, distance) in destinations {
        let result = results[source]?[destination]
        #expect(
          result?.distance == distance,
          Comment(rawValue: "\(testCase.name): \(source) to \(destination)"))
        let paths = testCase.expectedPaths[source]?[destination] ?? []
        if paths.isEmpty {
          #expect(
            result?.path == nil,
            Comment(rawValue: "\(testCase.name): path \(source) to \(destination)"))
        } else {
          #expect(
            result?.path.map { paths.contains($0) } == true,
            Comment(rawValue: "\(testCase.name): path \(source) to \(destination)"))
        }
      }
    }
  }
}

enum HeuristicKind: Sendable {
  case zero
  case towardD
}

struct AStarExpectation: Sendable {
  let distance: Double
  let paths: [[String]]
}

struct AStarCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let source: String
  let destination: String
  let heuristic: HeuristicKind
  let expected: Result<AStarExpectation, GraphError<String>>
}

@Suite("A*")
struct AStarTests {
  @Test(
    "Finds a minimum-weight route and validates its inputs",
    arguments: [
      AStarCase(
        name: "admissible heuristic finds the best route",
        fixture: GraphFixture(
          directed: true,
          edges: [
            TestEdge("A", "B", weight: 1), TestEdge("B", "D", weight: 2),
            TestEdge("A", "C", weight: 2), TestEdge("C", "D", weight: 1),
            TestEdge("A", "D", weight: 8),
          ]
        ),
        source: "A",
        destination: "D",
        heuristic: .towardD,
        expected: .success(
          AStarExpectation(distance: 3, paths: [["A", "B", "D"], ["A", "C", "D"]]))
      ),
      AStarCase(
        name: "unreachable target returns infinity and no path",
        fixture: GraphFixture(
          directed: true, vertices: ["D"], edges: [TestEdge("A", "B", weight: 1)]),
        source: "A",
        destination: "D",
        heuristic: .zero,
        expected: .success(AStarExpectation(distance: .infinity, paths: []))
      ),
      AStarCase(
        name: "source equals destination",
        fixture: GraphFixture(directed: true, vertices: ["A"]),
        source: "A",
        destination: "A",
        heuristic: .zero,
        expected: .success(AStarExpectation(distance: 0, paths: [["A"]]))
      ),
      AStarCase(
        name: "negative weights are rejected",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "D", weight: -1)]),
        source: "A",
        destination: "D",
        heuristic: .zero,
        expected: .failure(.negativeEdgeWeight(from: "A", to: "D"))
      ),
      AStarCase(
        name: "missing destination is reported",
        fixture: GraphFixture(directed: true, vertices: ["A"]),
        source: "A",
        destination: "D",
        heuristic: .zero,
        expected: .failure(.missingVertex("D"))
      ),
      AStarCase(
        name: "missing source is reported",
        fixture: GraphFixture(directed: true),
        source: "A",
        destination: "D",
        heuristic: .zero,
        expected: .failure(.missingVertex("A"))
      ),
    ])
  func aStar(_ testCase: AStarCase) throws {
    let graph = try makeGraph(testCase.fixture)
    let heuristic: @Sendable (String) -> Double = { vertex in
      switch testCase.heuristic {
      case .zero:
        return 0
      case .towardD:
        return vertex == "A" ? 2 : (vertex == "B" || vertex == "C" ? 1 : 0)
      }
    }
    switch testCase.expected {
    case .success(let expected):
      let result = try graph.aStar(
        from: testCase.source, to: testCase.destination, heuristic: heuristic)
      #expect(result.distance == expected.distance, Comment(rawValue: testCase.name))
      if expected.paths.isEmpty {
        #expect(result.path == nil, Comment(rawValue: testCase.name))
      } else {
        #expect(
          result.path.map { expected.paths.contains($0) } == true, Comment(rawValue: testCase.name))
      }
    case .failure(let error):
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        try graph.aStar(from: testCase.source, to: testCase.destination, heuristic: heuristic)
      }
    }
  }
}
