import Testing

@testable import GraphKit

private func componentSet(_ components: [[String]]) -> Set<Set<String>> {
  Set(components.map { Set($0) })
}

enum ComponentQuery: Sendable {
  case undirected
  case weak
  case strong
}

struct ComponentCase: Sendable {
  let name: String
  let query: ComponentQuery
  let fixture: GraphFixture
  let expected: Result<Set<Set<String>>, GraphError<String>>
}

struct ConnectedComponentCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let vertex: String
  let expected: Result<Set<String>, GraphError<String>>
}

struct CycleCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let expectedHasCycle: Bool
}

@Suite("Graph Components")
struct GraphComponentTests {
  @Test(
    "Returns connected, weakly connected, and strongly connected components",
    arguments: [
      ComponentCase(
        name: "undirected components include isolated vertices",
        query: .undirected,
        fixture: GraphFixture(
          directed: false,
          vertices: ["F"],
          edges: [TestEdge("A", "B"), TestEdge("B", "C"), TestEdge("D", "E")]
        ),
        expected: .success([["A", "B", "C"], ["D", "E"], ["F"]])
      ),
      ComponentCase(
        name: "empty undirected graph",
        query: .undirected,
        fixture: GraphFixture(directed: false),
        expected: .success([])
      ),
      ComponentCase(
        name: "weak components treat directed edges as bidirectional",
        query: .weak,
        fixture: GraphFixture(
          directed: true,
          vertices: ["F"],
          edges: [TestEdge("A", "B"), TestEdge("C", "B"), TestEdge("D", "E")]
        ),
        expected: .success([["A", "B", "C"], ["D", "E"], ["F"]])
      ),
      ComponentCase(
        name: "strong components separate one-way connections",
        query: .strong,
        fixture: GraphFixture(
          directed: true,
          vertices: ["F"],
          edges: [
            TestEdge("A", "B"), TestEdge("B", "C"), TestEdge("C", "A"),
            TestEdge("C", "D"), TestEdge("D", "E"), TestEdge("E", "D"),
          ]
        ),
        expected: .success([["A", "B", "C"], ["D", "E"], ["F"]])
      ),
      ComponentCase(
        name: "connected components require undirected graph",
        query: .undirected,
        fixture: GraphFixture(directed: true),
        expected: .failure(.directedGraphRequired)
      ),
      ComponentCase(
        name: "weak components require directed graph",
        query: .weak,
        fixture: GraphFixture(directed: false),
        expected: .failure(.undirectedGraphRequired)
      ),
      ComponentCase(
        name: "strong components require directed graph",
        query: .strong,
        fixture: GraphFixture(directed: false),
        expected: .failure(.undirectedGraphRequired)
      ),
    ])
  func componentQueries(_ testCase: ComponentCase) throws {
    let graph = try makeGraph(testCase.fixture)
    switch testCase.expected {
    case .success(let expected):
      let result: [[String]]
      switch testCase.query {
      case .undirected:
        result = try graph.connectedComponents()
      case .weak:
        result = try graph.weaklyConnectedComponents()
      case .strong:
        result = try graph.stronglyConnectedComponents()
      }
      #expect(componentSet(result) == expected, Comment(rawValue: testCase.name))
    case .failure(let error):
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        switch testCase.query {
        case .undirected:
          try graph.connectedComponents()
        case .weak:
          try graph.weaklyConnectedComponents()
        case .strong:
          try graph.stronglyConnectedComponents()
        }
      }
    }
  }

  @Test(
    "Returns the component containing a vertex",
    arguments: [
      ConnectedComponentCase(
        name: "returns the matching undirected component",
        fixture: GraphFixture(
          directed: false,
          vertices: ["D"],
          edges: [TestEdge("A", "B"), TestEdge("B", "C")]
        ),
        vertex: "B",
        expected: .success(["A", "B", "C"])
      ),
      ConnectedComponentCase(
        name: "missing vertex",
        fixture: GraphFixture(directed: false),
        vertex: "A",
        expected: .failure(.missingVertex("A"))
      ),
      ConnectedComponentCase(
        name: "requires undirected graph",
        fixture: GraphFixture(directed: true, vertices: ["A"]),
        vertex: "A",
        expected: .failure(.directedGraphRequired)
      ),
    ])
  func connectedComponent(_ testCase: ConnectedComponentCase) throws {
    let graph = try makeGraph(testCase.fixture)
    switch testCase.expected {
    case .success(let expected):
      let result = try graph.connectedComponent(containing: testCase.vertex)
      #expect(Set(result) == expected, Comment(rawValue: testCase.name))
    case .failure(let error):
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        try graph.connectedComponent(containing: testCase.vertex)
      }
    }
  }
}

@Suite("Graph Cycles")
struct GraphCycleTests {
  @Test(
    "Detects directed and undirected cycles",
    arguments: [
      CycleCase(
        name: "directed acyclic graph",
        fixture: GraphFixture(
          directed: true, edges: [TestEdge("A", "B"), TestEdge("A", "C"), TestEdge("B", "D")]),
        expectedHasCycle: false
      ),
      CycleCase(
        name: "directed cycle in a disconnected component",
        fixture: GraphFixture(
          directed: true,
          vertices: ["A"],
          edges: [TestEdge("B", "C"), TestEdge("C", "D"), TestEdge("D", "B")]
        ),
        expectedHasCycle: true
      ),
      CycleCase(
        name: "directed self-loop",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "A")]),
        expectedHasCycle: true
      ),
      CycleCase(
        name: "undirected tree",
        fixture: GraphFixture(
          directed: false, edges: [TestEdge("A", "B"), TestEdge("A", "C"), TestEdge("C", "D")]),
        expectedHasCycle: false
      ),
      CycleCase(
        name: "undirected cycle",
        fixture: GraphFixture(
          directed: false, edges: [TestEdge("A", "B"), TestEdge("B", "C"), TestEdge("C", "A")]),
        expectedHasCycle: true
      ),
      CycleCase(
        name: "undirected self-loop",
        fixture: GraphFixture(directed: false, edges: [TestEdge("A", "A")]),
        expectedHasCycle: true
      ),
      CycleCase(
        name: "empty graph",
        fixture: GraphFixture(directed: false),
        expectedHasCycle: false
      ),
    ])
  func detectsCycles(_ testCase: CycleCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(graph.hasCycle() == testCase.expectedHasCycle, Comment(rawValue: testCase.name))
  }
}
