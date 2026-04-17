import Testing

@testable import GraphKit

struct ShortestPathExpectation: Sendable {
  let paths: [[String]]?
  let distance: Double?
}

struct ShortestPathCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let source: String
  let destination: String
  let expected: Result<ShortestPathExpectation, GraphError<String>>
}

@Suite("Shortest Paths")
struct ShortestPathTests {
  @Test(
    "Finds minimum-weight routes and distances",
    arguments: [
      ShortestPathCase(
        name: "chooses a lighter multi-edge path",
        fixture: GraphFixture(
          directed: true,
          edges: [
            TestEdge("A", "B", weight: 6),
            TestEdge("A", "C", weight: 2),
            TestEdge("C", "B", weight: 1),
            TestEdge("B", "D", weight: 2),
            TestEdge("C", "D", weight: 9),
          ]
        ),
        source: "A",
        destination: "D",
        expected: .success(ShortestPathExpectation(paths: [["A", "C", "B", "D"]], distance: 5))
      ),
      ShortestPathCase(
        name: "either equal-weight route is valid",
        fixture: GraphFixture(
          directed: true,
          edges: [
            TestEdge("A", "B", weight: 1), TestEdge("A", "C", weight: 1),
            TestEdge("B", "D", weight: 1), TestEdge("C", "D", weight: 1),
          ]
        ),
        source: "A",
        destination: "D",
        expected: .success(
          ShortestPathExpectation(
            paths: [["A", "B", "D"], ["A", "C", "D"]],
            distance: 2
          ))
      ),
      ShortestPathCase(
        name: "traverses an undirected edge in reverse",
        fixture: GraphFixture(
          directed: false, edges: [TestEdge("A", "B", weight: 4), TestEdge("B", "C", weight: 1)]),
        source: "C",
        destination: "A",
        expected: .success(ShortestPathExpectation(paths: [["C", "B", "A"]], distance: 5))
      ),
      ShortestPathCase(
        name: "source equals destination",
        fixture: GraphFixture(directed: true, vertices: ["A"]),
        source: "A",
        destination: "A",
        expected: .success(ShortestPathExpectation(paths: [["A"]], distance: 0))
      ),
      ShortestPathCase(
        name: "unreachable destination",
        fixture: GraphFixture(
          directed: true, vertices: ["C"], edges: [TestEdge("A", "B", weight: 1)]),
        source: "A",
        destination: "C",
        expected: .success(ShortestPathExpectation(paths: nil, distance: nil))
      ),
      ShortestPathCase(
        name: "directed edges are not traversed in reverse",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B", weight: 1)]),
        source: "B",
        destination: "A",
        expected: .success(ShortestPathExpectation(paths: nil, distance: nil))
      ),
      ShortestPathCase(
        name: "negative edge is rejected",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B", weight: -1)]),
        source: "A",
        destination: "B",
        expected: .failure(.negativeEdgeWeight(from: "A", to: "B"))
      ),
      ShortestPathCase(
        name: "missing source",
        fixture: GraphFixture(directed: true),
        source: "A",
        destination: "B",
        expected: .failure(.missingVertex("A"))
      ),
      ShortestPathCase(
        name: "missing destination",
        fixture: GraphFixture(directed: true, vertices: ["A"]),
        source: "A",
        destination: "B",
        expected: .failure(.missingVertex("B"))
      ),
    ])
  func shortestPathAndDistance(_ testCase: ShortestPathCase) throws {
    let graph = try makeGraph(testCase.fixture)
    switch testCase.expected {
    case .success(let expected):
      let path = try graph.shortestPath(from: testCase.source, to: testCase.destination)
      let distance = try graph.shortestDistance(from: testCase.source, to: testCase.destination)
      if let expectedPaths = expected.paths {
        #expect(path.map { expectedPaths.contains($0) } == true, Comment(rawValue: testCase.name))
      } else {
        #expect(path == nil, Comment(rawValue: testCase.name))
      }
      #expect(distance == expected.distance, Comment(rawValue: testCase.name))
    case .failure(let error):
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        try graph.shortestPath(from: testCase.source, to: testCase.destination)
      }
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        try graph.shortestDistance(from: testCase.source, to: testCase.destination)
      }
    }
  }
}
