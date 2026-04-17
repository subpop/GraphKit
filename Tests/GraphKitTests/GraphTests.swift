import Testing

@testable import GraphKit

// MARK: - Test Fixtures

struct TestEdge: Sendable {
  let from: String
  let to: String
  let weight: Double

  init(_ from: String, _ to: String, weight: Double = 0.0) {
    self.from = from
    self.to = to
    self.weight = weight
  }
}

struct GraphFixture: Sendable {
  let directed: Bool
  let vertices: [String]
  let edges: [TestEdge]

  init(directed: Bool, vertices: [String] = [], edges: [TestEdge] = []) {
    self.directed = directed
    self.vertices = vertices
    self.edges = edges
  }
}

func makeGraph(_ fixture: GraphFixture) throws -> Graph<String> {
  var graph = Graph<String>(directed: fixture.directed)
  for vertex in fixture.vertices {
    try graph.addVertex(vertex)
  }
  for edge in fixture.edges {
    try graph.addEdge(from: edge.from, to: edge.to, weight: edge.weight)
  }
  return graph
}

// MARK: - Initialization

struct GraphInitializationCase: Sendable {
  let name: String
  let directed: Bool
  let expectedDirected: Bool
  let expectedVertexCount: Int
  let expectedEdgeCount: Int
}

enum VertexTypeKind: Sendable {
  case string
  case integer
}

struct VertexTypeCase: Sendable {
  let name: String
  let kind: VertexTypeKind
  let expectedVertexCount: Int
}

@Suite("Graph Initialization")
struct GraphInitTests {
  @Test(
    "Initializes empty directed and undirected graphs",
    arguments: [
      GraphInitializationCase(
        name: "directed",
        directed: true,
        expectedDirected: true,
        expectedVertexCount: 0,
        expectedEdgeCount: 0
      ),
      GraphInitializationCase(
        name: "undirected",
        directed: false,
        expectedDirected: false,
        expectedVertexCount: 0,
        expectedEdgeCount: 0
      ),
    ])
  func initializesEmptyGraph(_ testCase: GraphInitializationCase) {
    let graph = Graph<String>(directed: testCase.directed)
    #expect(graph.isDirected == testCase.expectedDirected, Comment(rawValue: testCase.name))
    #expect(graph.vertexCount == testCase.expectedVertexCount, Comment(rawValue: testCase.name))
    #expect(graph.edgeCount == testCase.expectedEdgeCount, Comment(rawValue: testCase.name))
  }

  @Test(
    "Supports generic hashable vertex types",
    arguments: [
      VertexTypeCase(name: "string vertices", kind: .string, expectedVertexCount: 0),
      VertexTypeCase(name: "integer vertices", kind: .integer, expectedVertexCount: 0),
    ])
  func supportsVertexTypes(_ testCase: VertexTypeCase) {
    let vertexCount: Int
    switch testCase.kind {
    case .string:
      vertexCount = Graph<String>(directed: true).vertexCount
    case .integer:
      vertexCount = Graph<Int>(directed: true).vertexCount
    }
    #expect(vertexCount == testCase.expectedVertexCount, Comment(rawValue: testCase.name))
  }
}

// MARK: - Vertex Operations

enum VertexInsertionKind: Sendable {
  case single
  case batch
}

struct VertexInsertionCase: Sendable {
  let name: String
  let kind: VertexInsertionKind
  let vertices: [String]
  let expectedVertices: Set<String>
}

struct DuplicateVertexCase: Sendable {
  let name: String
  let kind: VertexInsertionKind
  let vertices: [String]
  let existingVertices: [String]
  let expectedVertices: Set<String>
  let expectedError: GraphError<String>
}

struct VertexRemovalCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let vertex: String
  let expectedVertices: Set<String>
  let expectedEdgeCount: Int
}

@Suite("Vertex Operations")
struct VertexOperationTests {
  @Test(
    "Adds one or multiple vertices",
    arguments: [
      VertexInsertionCase(
        name: "single vertex", kind: .single, vertices: ["A"], expectedVertices: ["A"]),
      VertexInsertionCase(
        name: "batch", kind: .batch, vertices: ["A", "B", "C"], expectedVertices: ["A", "B", "C"]),
    ])
  func addsVertices(_ testCase: VertexInsertionCase) throws {
    var graph = Graph<String>(directed: true)
    switch testCase.kind {
    case .single:
      try graph.addVertex(testCase.vertices[0])
    case .batch:
      try graph.addVertices(testCase.vertices[0], testCase.vertices[1], testCase.vertices[2])
    }
    #expect(Set(graph.allVertices()) == testCase.expectedVertices, Comment(rawValue: testCase.name))
  }

  @Test(
    "Duplicate vertex insertion throws and retains prior insertions",
    arguments: [
      DuplicateVertexCase(
        name: "duplicate single vertex",
        kind: .single,
        vertices: ["A"],
        existingVertices: ["A"],
        expectedVertices: ["A"],
        expectedError: .duplicateVertex("A")
      ),
      DuplicateVertexCase(
        name: "duplicate in batch",
        kind: .batch,
        vertices: ["A", "B", "A"],
        existingVertices: [],
        expectedVertices: ["A", "B"],
        expectedError: .duplicateVertex("A")
      ),
    ])
  func duplicateVertexThrows(_ testCase: DuplicateVertexCase) throws {
    var graph = try makeGraph(GraphFixture(directed: true, vertices: testCase.existingVertices))
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      switch testCase.kind {
      case .single:
        try graph.addVertex(testCase.vertices[0])
      case .batch:
        try graph.addVertices(testCase.vertices[0], testCase.vertices[1], testCase.vertices[2])
      }
    }
    #expect(Set(graph.allVertices()) == testCase.expectedVertices, Comment(rawValue: testCase.name))
  }

  @Test(
    "Removing a vertex removes all incident edges",
    arguments: [
      VertexRemovalCase(
        name: "directed inbound and outbound edges",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B"), TestEdge("C", "A")]),
        vertex: "A",
        expectedVertices: ["B", "C"],
        expectedEdgeCount: 0
      ),
      VertexRemovalCase(
        name: "undirected edges",
        fixture: GraphFixture(directed: false, edges: [TestEdge("A", "B"), TestEdge("A", "C")]),
        vertex: "A",
        expectedVertices: ["B", "C"],
        expectedEdgeCount: 0
      ),
    ])
  func removesVertexAndIncidentEdges(_ testCase: VertexRemovalCase) throws {
    var graph = try makeGraph(testCase.fixture)
    try graph.removeVertex(testCase.vertex)
    #expect(Set(graph.allVertices()) == testCase.expectedVertices, Comment(rawValue: testCase.name))
    #expect(graph.edgeCount == testCase.expectedEdgeCount, Comment(rawValue: testCase.name))
  }

  @Test(
    "Removing a missing vertex throws",
    arguments: [
      GraphErrorCase(
        name: "vertex is absent",
        fixture: GraphFixture(directed: true),
        expectedError: .missingVertex("A")
      )
    ])
  func removeMissingVertexThrows(_ testCase: GraphErrorCase) throws {
    var graph = try makeGraph(testCase.fixture)
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      try graph.removeVertex("A")
    }
  }
}

// MARK: - Edge Operations

struct GraphErrorCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let expectedError: GraphError<String>
}

struct EdgeInsertionCase: Sendable {
  let name: String
  let directed: Bool
  let weight: Double?
  let expectedWeight: Double
  let expectedEdgeCount: Int
  let expectedVertices: Set<String>
}

struct DuplicateEdgeCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let from: String
  let to: String
  let expectedError: GraphError<String>
}

struct EdgeRemovalCase: Sendable {
  let name: String
  let directed: Bool
  let expectedRemainingEdges: Int
}

struct EdgeRemovalErrorCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let from: String
  let to: String
  let expectedError: GraphError<String>
}

struct EdgeWeightCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let from: String
  let to: String
  let expectedWeight: Double
}

struct EdgeWeightErrorCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let from: String
  let to: String
  let expectedError: GraphError<String>
}

struct EdgeMembershipCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let from: String
  let to: String
  let expected: Bool
}

@Suite("Edge Operations")
struct EdgeOperationTests {
  @Test(
    "Adding an edge creates missing vertices and stores its weight",
    arguments: [
      EdgeInsertionCase(
        name: "default weight",
        directed: true,
        weight: nil,
        expectedWeight: 0.0,
        expectedEdgeCount: 1,
        expectedVertices: ["A", "B"]
      ),
      EdgeInsertionCase(
        name: "explicit directed weight",
        directed: true,
        weight: 3.5,
        expectedWeight: 3.5,
        expectedEdgeCount: 1,
        expectedVertices: ["A", "B"]
      ),
      EdgeInsertionCase(
        name: "explicit undirected weight",
        directed: false,
        weight: 7.0,
        expectedWeight: 7.0,
        expectedEdgeCount: 1,
        expectedVertices: ["A", "B"]
      ),
    ])
  func addsEdge(_ testCase: EdgeInsertionCase) throws {
    var graph = Graph<String>(directed: testCase.directed)
    if let weight = testCase.weight {
      try graph.addEdge(from: "A", to: "B", weight: weight)
    } else {
      try graph.addEdge(from: "A", to: "B")
    }
    #expect(Set(graph.allVertices()) == testCase.expectedVertices, Comment(rawValue: testCase.name))
    #expect(graph.edgeCount == testCase.expectedEdgeCount, Comment(rawValue: testCase.name))
    #expect(
      try graph.edgeWeight(from: "A", to: "B") == testCase.expectedWeight,
      Comment(rawValue: testCase.name))
  }

  @Test(
    "Adding a duplicate edge throws",
    arguments: [
      DuplicateEdgeCase(
        name: "same directed edge",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B")]),
        from: "A",
        to: "B",
        expectedError: .duplicateEdge(from: "A", to: "B")
      ),
      DuplicateEdgeCase(
        name: "reverse of undirected edge",
        fixture: GraphFixture(directed: false, edges: [TestEdge("A", "B")]),
        from: "B",
        to: "A",
        expectedError: .duplicateEdge(from: "B", to: "A")
      ),
    ])
  func duplicateEdgeThrows(_ testCase: DuplicateEdgeCase) throws {
    var graph = try makeGraph(testCase.fixture)
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      try graph.addEdge(from: testCase.from, to: testCase.to)
    }
  }

  @Test(
    "Removing an edge preserves vertices and removes the relationship",
    arguments: [
      EdgeRemovalCase(name: "directed", directed: true, expectedRemainingEdges: 1),
      EdgeRemovalCase(name: "undirected", directed: false, expectedRemainingEdges: 1),
    ])
  func removesEdge(_ testCase: EdgeRemovalCase) throws {
    var graph = try makeGraph(
      GraphFixture(directed: testCase.directed, edges: [TestEdge("A", "B"), TestEdge("B", "C")])
    )
    try graph.removeEdge(from: "A", to: "B")
    #expect(graph.edgeCount == testCase.expectedRemainingEdges, Comment(rawValue: testCase.name))
    #expect(Set(graph.allVertices()) == ["A", "B", "C"], Comment(rawValue: testCase.name))
    #expect(!graph.hasEdge(from: "A", to: "B"), Comment(rawValue: testCase.name))
    #expect(!graph.hasEdge(from: "B", to: "A"), Comment(rawValue: testCase.name))
  }

  @Test(
    "Removing an invalid edge throws the appropriate error",
    arguments: [
      EdgeRemovalErrorCase(
        name: "missing source",
        fixture: GraphFixture(directed: true),
        from: "A",
        to: "B",
        expectedError: .missingVertex("A")
      ),
      EdgeRemovalErrorCase(
        name: "missing destination",
        fixture: GraphFixture(directed: true, vertices: ["A"]),
        from: "A",
        to: "B",
        expectedError: .missingVertex("B")
      ),
      EdgeRemovalErrorCase(
        name: "missing edge",
        fixture: GraphFixture(directed: true, vertices: ["A", "B"]),
        from: "A",
        to: "B",
        expectedError: .missingEdge(from: "A", to: "B")
      ),
    ])
  func removeInvalidEdgeThrows(_ testCase: EdgeRemovalErrorCase) throws {
    var graph = try makeGraph(testCase.fixture)
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      try graph.removeEdge(from: testCase.from, to: testCase.to)
    }
  }

  @Test(
    "Edge existence follows directionality",
    arguments: [
      EdgeMembershipCase(
        name: "directed forward edge exists",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B")]),
        from: "A",
        to: "B",
        expected: true
      ),
      EdgeMembershipCase(
        name: "directed reverse edge is absent",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B")]),
        from: "B",
        to: "A",
        expected: false
      ),
      EdgeMembershipCase(
        name: "missing endpoints",
        fixture: GraphFixture(directed: true),
        from: "A",
        to: "B",
        expected: false
      ),
    ])
  func edgeMembership(_ testCase: EdgeMembershipCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(
      graph.hasEdge(from: testCase.from, to: testCase.to) == testCase.expected,
      Comment(rawValue: testCase.name))
  }

  @Test(
    "Edge weight can be queried in directed and undirected graphs",
    arguments: [
      EdgeWeightCase(
        name: "directed edge",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B", weight: 4.5)]),
        from: "A",
        to: "B",
        expectedWeight: 4.5
      ),
      EdgeWeightCase(
        name: "undirected reverse edge",
        fixture: GraphFixture(directed: false, edges: [TestEdge("A", "B", weight: 7.0)]),
        from: "B",
        to: "A",
        expectedWeight: 7.0
      ),
    ])
  func edgeWeight(_ testCase: EdgeWeightCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(
      try graph.edgeWeight(from: testCase.from, to: testCase.to) == testCase.expectedWeight,
      Comment(rawValue: testCase.name)
    )
  }

  @Test(
    "Querying an invalid edge weight throws",
    arguments: [
      EdgeWeightErrorCase(
        name: "missing source vertex",
        fixture: GraphFixture(directed: true),
        from: "A",
        to: "B",
        expectedError: .missingVertex("A")
      ),
      EdgeWeightErrorCase(
        name: "missing destination vertex",
        fixture: GraphFixture(directed: true, vertices: ["A"]),
        from: "A",
        to: "B",
        expectedError: .missingVertex("B")
      ),
      EdgeWeightErrorCase(
        name: "missing edge",
        fixture: GraphFixture(directed: true, vertices: ["A", "B"]),
        from: "A",
        to: "B",
        expectedError: .missingEdge(from: "A", to: "B")
      ),
    ])
  func missingEdgeWeightThrows(_ testCase: EdgeWeightErrorCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      try graph.edgeWeight(from: testCase.from, to: testCase.to)
    }
  }
}

// MARK: - Graph Queries

struct VertexMembershipCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let vertex: String
  let expected: Bool
}

struct VertexEnumerationCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let expected: Set<String>
}

struct NeighborCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let vertex: String
  let direction: Direction
  let expectedNeighbors: Set<String>
}

struct NeighborErrorCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let vertex: String
  let expectedError: GraphError<String>
}

struct DegreeCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let vertex: String
  let kind: DegreeKind
  let expected: Result<Int, GraphError<String>>
}

enum DegreeKind: Sendable {
  case degree
  case inDegree
  case outDegree
}

func degree(_ kind: DegreeKind, of vertex: String, in graph: Graph<String>) throws -> Int {
  switch kind {
  case .degree:
    try graph.degree(of: vertex)
  case .inDegree:
    try graph.inDegree(of: vertex)
  case .outDegree:
    try graph.outDegree(of: vertex)
  }
}

struct EdgeEnumerationCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let expectedEdgeCount: Int
}

struct DescriptionCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let expectedFragments: [String]
}

@Suite("Graph Queries")
struct GraphQueryTests {
  @Test(
    "Vertex membership",
    arguments: [
      VertexMembershipCase(
        name: "present", fixture: GraphFixture(directed: true, vertices: ["A"]), vertex: "A",
        expected: true),
      VertexMembershipCase(
        name: "absent", fixture: GraphFixture(directed: true), vertex: "A", expected: false),
    ])
  func vertexMembership(_ testCase: VertexMembershipCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(graph.hasVertex(testCase.vertex) == testCase.expected, Comment(rawValue: testCase.name))
  }

  @Test(
    "Enumerates vertices",
    arguments: [
      VertexEnumerationCase(
        name: "isolated and edge-connected vertices",
        fixture: GraphFixture(
          directed: true, vertices: ["D"], edges: [TestEdge("A", "B"), TestEdge("B", "C")]),
        expected: ["A", "B", "C", "D"]
      )
    ])
  func allVertices(_ testCase: VertexEnumerationCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(Set(graph.allVertices()) == testCase.expected, Comment(rawValue: testCase.name))
  }

  @Test(
    "Neighbors respect graph direction",
    arguments: [
      NeighborCase(
        name: "outbound",
        fixture: GraphFixture(
          directed: true, edges: [TestEdge("A", "B"), TestEdge("C", "B"), TestEdge("B", "D")]),
        vertex: "B",
        direction: .outbound,
        expectedNeighbors: ["D"]
      ),
      NeighborCase(
        name: "inbound",
        fixture: GraphFixture(
          directed: true, edges: [TestEdge("A", "B"), TestEdge("C", "B"), TestEdge("B", "D")]),
        vertex: "B",
        direction: .inbound,
        expectedNeighbors: ["A", "C"]
      ),
      NeighborCase(
        name: "both directions",
        fixture: GraphFixture(
          directed: true, edges: [TestEdge("A", "B"), TestEdge("C", "B"), TestEdge("B", "D")]),
        vertex: "B",
        direction: .noDirection,
        expectedNeighbors: ["A", "C", "D"]
      ),
      NeighborCase(
        name: "direction ignored for undirected graph",
        fixture: GraphFixture(directed: false, edges: [TestEdge("A", "B"), TestEdge("C", "B")]),
        vertex: "B",
        direction: .inbound,
        expectedNeighbors: ["A", "C"]
      ),
    ])
  func neighbors(_ testCase: NeighborCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(
      Set(try graph.neighbors(of: testCase.vertex, direction: testCase.direction))
        == testCase.expectedNeighbors,
      Comment(rawValue: testCase.name)
    )
  }

  @Test(
    "Querying neighbors of a missing vertex throws",
    arguments: [
      NeighborErrorCase(
        name: "missing vertex",
        fixture: GraphFixture(directed: true),
        vertex: "A",
        expectedError: .missingVertex("A")
      )
    ])
  func missingNeighborsThrows(_ testCase: NeighborErrorCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      try graph.neighbors(of: testCase.vertex)
    }
  }

  @Test(
    "Degree queries for directed and undirected graphs",
    arguments: [
      DegreeCase(
        name: "undirected degree",
        fixture: GraphFixture(
          directed: false, edges: [TestEdge("A", "B"), TestEdge("A", "C"), TestEdge("A", "D")]),
        vertex: "A",
        kind: .degree,
        expected: .success(3)
      ),
      DegreeCase(
        name: "undirected leaf degree",
        fixture: GraphFixture(directed: false, edges: [TestEdge("A", "B")]),
        vertex: "B",
        kind: .degree,
        expected: .success(1)
      ),
      DegreeCase(
        name: "directed in-degree",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "C"), TestEdge("B", "C")]),
        vertex: "C",
        kind: .inDegree,
        expected: .success(2)
      ),
      DegreeCase(
        name: "directed out-degree",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B"), TestEdge("A", "C")]),
        vertex: "A",
        kind: .outDegree,
        expected: .success(2)
      ),
      DegreeCase(
        name: "degree requires undirected graph",
        fixture: GraphFixture(directed: true, vertices: ["A"]),
        vertex: "A",
        kind: .degree,
        expected: .failure(.undirectedGraphRequired)
      ),
      DegreeCase(
        name: "in-degree requires directed graph",
        fixture: GraphFixture(directed: false, vertices: ["A"]),
        vertex: "A",
        kind: .inDegree,
        expected: .failure(.directedGraphRequired)
      ),
      DegreeCase(
        name: "out-degree requires directed graph",
        fixture: GraphFixture(directed: false, vertices: ["A"]),
        vertex: "A",
        kind: .outDegree,
        expected: .failure(.directedGraphRequired)
      ),
      DegreeCase(
        name: "degree rejects missing vertex",
        fixture: GraphFixture(directed: false),
        vertex: "A",
        kind: .degree,
        expected: .failure(.missingVertex("A"))
      ),
      DegreeCase(
        name: "in-degree rejects missing vertex",
        fixture: GraphFixture(directed: true),
        vertex: "A",
        kind: .inDegree,
        expected: .failure(.missingVertex("A"))
      ),
      DegreeCase(
        name: "out-degree rejects missing vertex",
        fixture: GraphFixture(directed: true),
        vertex: "A",
        kind: .outDegree,
        expected: .failure(.missingVertex("A"))
      ),
    ])
  func degreeQueries(_ testCase: DegreeCase) throws {
    let graph = try makeGraph(testCase.fixture)
    switch testCase.expected {
    case .success(let expected):
      #expect(
        try degree(testCase.kind, of: testCase.vertex, in: graph) == expected,
        Comment(rawValue: testCase.name))
    case .failure(let error):
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        try degree(testCase.kind, of: testCase.vertex, in: graph)
      }
    }
  }

  @Test(
    "Enumerates each edge once",
    arguments: [
      EdgeEnumerationCase(
        name: "directed edges",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B"), TestEdge("B", "C")]),
        expectedEdgeCount: 2
      ),
      EdgeEnumerationCase(
        name: "undirected edges",
        fixture: GraphFixture(directed: false, edges: [TestEdge("A", "B"), TestEdge("B", "C")]),
        expectedEdgeCount: 2
      ),
    ])
  func allEdges(_ testCase: EdgeEnumerationCase) throws {
    let graph = try makeGraph(testCase.fixture)
    #expect(graph.allEdges().count == testCase.expectedEdgeCount, Comment(rawValue: testCase.name))
  }

  @Test(
    "Graph description includes its expected content",
    arguments: [
      DescriptionCase(
        name: "empty graph",
        fixture: GraphFixture(directed: true),
        expectedFragments: ["Graph"]
      ),
      DescriptionCase(
        name: "graph with an edge",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B", weight: 1.0)]),
        expectedFragments: ["A", "B"]
      ),
    ])
  func description(_ testCase: DescriptionCase) throws {
    let graph = try makeGraph(testCase.fixture)
    let includesExpectedContent = testCase.expectedFragments.allSatisfy {
      graph.description.contains($0)
    }
    #expect(includesExpectedContent, Comment(rawValue: testCase.name))
  }
}

// MARK: - Traversal

struct TraversalCase: Sendable {
  let name: String
  let direction: Direction
  let expectedLevels: [[String]]
}

enum TraversalMethod: Sendable {
  case depthFirstSearch
  case breadthFirstSearch
}

enum VisitorMethod: Sendable {
  case depthFirstVisit
  case breadthFirstVisit
}

struct VisitorMethodCase: Sendable {
  let name: String
  let method: VisitorMethod
  let expectedVisitedCount: Int
  let expectedFirstVertex: String
}

struct TraversalOperationCase: Sendable {
  let name: String
  let method: TraversalOperation
  let expectedError: GraphError<String>
}

enum TraversalOperation: Sendable {
  case depthFirstSearch
  case breadthFirstSearch
  case depthFirstVisit
  case breadthFirstVisit
}

@Suite("Graph Traversal")
struct GraphTraversalTests {
  @Test(
    "Traversal follows direction and visits each reachable vertex once",
    arguments: [
      TraversalCase(
        name: "both directions", direction: .noDirection,
        expectedLevels: [["A"], ["B", "C", "D"], ["E"]]),
      TraversalCase(
        name: "outbound", direction: .outbound, expectedLevels: [["A"], ["B", "C"], ["D", "E"]]),
      TraversalCase(name: "inbound", direction: .inbound, expectedLevels: [["A"], ["D"], ["B"]]),
    ])
  func traversalFollowsDirection(_ testCase: TraversalCase) throws {
    let fixture = GraphFixture(
      directed: true,
      edges: [
        TestEdge("A", "B"), TestEdge("A", "C"), TestEdge("B", "D"), TestEdge("C", "E"),
        TestEdge("D", "A"),
      ]
    )
    let graph = try makeGraph(fixture)
    let depthFirst = try graph.depthFirstSearch(from: "A", direction: testCase.direction)
    let breadthFirst = try graph.breadthFirstSearch(from: "A", direction: testCase.direction)
    let expected = Set(testCase.expectedLevels.flatMap { $0 })

    #expect(Set(depthFirst) == expected, Comment(rawValue: testCase.name))
    #expect(depthFirst.count == expected.count, Comment(rawValue: testCase.name))
    #expect(Set(breadthFirst) == expected, Comment(rawValue: testCase.name))
    #expect(breadthFirst.count == expected.count, Comment(rawValue: testCase.name))

    var offset = 0
    for level in testCase.expectedLevels {
      #expect(
        Set(breadthFirst.dropFirst(offset).prefix(level.count)) == Set(level),
        Comment(rawValue: testCase.name)
      )
      offset += level.count
    }
  }

  @Test(
    "Traversal visitors stop early",
    arguments: [
      VisitorMethodCase(
        name: "depth first",
        method: .depthFirstVisit,
        expectedVisitedCount: 2,
        expectedFirstVertex: "A"
      ),
      VisitorMethodCase(
        name: "breadth first",
        method: .breadthFirstVisit,
        expectedVisitedCount: 2,
        expectedFirstVertex: "A"
      ),
    ])
  func visitorStopsEarly(_ testCase: VisitorMethodCase) throws {
    let graph = try makeGraph(
      GraphFixture(directed: true, edges: [TestEdge("A", "B"), TestEdge("A", "C")]))
    var visited: [String] = []
    let visitor: (String) -> Bool = { vertex in
      visited.append(vertex)
      return vertex != "A"
    }

    switch testCase.method {
    case .depthFirstVisit:
      try graph.depthFirstVisit(from: "A", visitor: visitor)
    case .breadthFirstVisit:
      try graph.breadthFirstVisit(from: "A", visitor: visitor)
    }

    #expect(visited.count == testCase.expectedVisitedCount, Comment(rawValue: testCase.name))
    #expect(visited.first == testCase.expectedFirstVertex, Comment(rawValue: testCase.name))
  }

  @Test(
    "Traversal operations throw for a missing start vertex",
    arguments: [
      TraversalOperationCase(
        name: "depth-first search",
        method: .depthFirstSearch,
        expectedError: .missingVertex("A")
      ),
      TraversalOperationCase(
        name: "breadth-first search",
        method: .breadthFirstSearch,
        expectedError: .missingVertex("A")
      ),
      TraversalOperationCase(
        name: "depth-first visitor",
        method: .depthFirstVisit,
        expectedError: .missingVertex("A")
      ),
      TraversalOperationCase(
        name: "breadth-first visitor",
        method: .breadthFirstVisit,
        expectedError: .missingVertex("A")
      ),
    ])
  func missingStartThrows(_ testCase: TraversalOperationCase) {
    let graph = Graph<String>(directed: true)
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      switch testCase.method {
      case .depthFirstSearch:
        _ = try graph.depthFirstSearch(from: "A")
      case .breadthFirstSearch:
        _ = try graph.breadthFirstSearch(from: "A")
      case .depthFirstVisit:
        try graph.depthFirstVisit(from: "A") { _ in false }
      case .breadthFirstVisit:
        try graph.breadthFirstVisit(from: "A") { _ in false }
      }
    }
  }
}

// MARK: - Neighborhood

struct NeighborhoodCase: Sendable {
  let name: String
  let maximumDistance: Int
  let minimumDistance: Int
  let direction: Direction
  let expected: Set<String>
}

struct DistanceRangeCase: Sendable {
  let name: String
  let minimumDistance: Int
  let maximumDistance: Int
  let expectedError: GraphError<String>
}

struct MissingNeighborhoodCase: Sendable {
  let name: String
  let vertex: String
  let expectedError: GraphError<String>
}

@Suite("Graph Neighborhood")
struct GraphNeighborhoodTests {
  @Test(
    "Neighborhood respects hop distance and direction",
    arguments: [
      NeighborhoodCase(
        name: "from origin through distance two", maximumDistance: 2, minimumDistance: 0,
        direction: .noDirection, expected: ["A", "B", "C", "E"]),
      NeighborhoodCase(
        name: "distances two through three", maximumDistance: 3, minimumDistance: 2,
        direction: .outbound, expected: ["C", "D"]),
      NeighborhoodCase(
        name: "inbound neighbors", maximumDistance: 1, minimumDistance: 0, direction: .inbound,
        expected: ["A", "E"]),
      NeighborhoodCase(
        name: "origin only", maximumDistance: 0, minimumDistance: 0, direction: .noDirection,
        expected: ["A"]),
    ])
  func neighborhoodRespectsDistanceRange(_ testCase: NeighborhoodCase) throws {
    let graph = try makeGraph(
      GraphFixture(
        directed: true,
        edges: [
          TestEdge("A", "B"), TestEdge("B", "C"), TestEdge("C", "D"), TestEdge("A", "E"),
          TestEdge("E", "A"),
        ]
      )
    )
    let result = try graph.neighborhood(
      of: "A",
      maximumDistance: testCase.maximumDistance,
      minimumDistance: testCase.minimumDistance,
      direction: testCase.direction
    )
    #expect(Set(result) == testCase.expected, Comment(rawValue: testCase.name))
  }

  @Test(
    "Neighborhood rejects invalid distance ranges",
    arguments: [
      DistanceRangeCase(
        name: "minimum greater than maximum",
        minimumDistance: 2,
        maximumDistance: 1,
        expectedError: .invalidDistanceRange(minimum: 2, maximum: 1)
      ),
      DistanceRangeCase(
        name: "negative minimum",
        minimumDistance: -1,
        maximumDistance: 1,
        expectedError: .invalidDistanceRange(minimum: -1, maximum: 1)
      ),
      DistanceRangeCase(
        name: "negative maximum",
        minimumDistance: 0,
        maximumDistance: -1,
        expectedError: .invalidDistanceRange(minimum: 0, maximum: -1)
      ),
    ])
  func rejectsInvalidDistanceRange(_ testCase: DistanceRangeCase) throws {
    let graph = try makeGraph(GraphFixture(directed: true, vertices: ["A"]))
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      try graph.neighborhood(
        of: "A",
        maximumDistance: testCase.maximumDistance,
        minimumDistance: testCase.minimumDistance
      )
    }
  }

  @Test(
    "Neighborhood query throws for a missing start vertex",
    arguments: [
      MissingNeighborhoodCase(
        name: "unknown vertex",
        vertex: "A",
        expectedError: .missingVertex("A")
      )
    ])
  func missingStartThrows(_ testCase: MissingNeighborhoodCase) {
    let graph = Graph<String>(directed: true)
    #expect(throws: testCase.expectedError, Comment(rawValue: testCase.name)) {
      try graph.neighborhood(of: testCase.vertex, maximumDistance: 1)
    }
  }
}
