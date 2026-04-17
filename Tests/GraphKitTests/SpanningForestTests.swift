import Testing

@testable import GraphKit

struct SpanningForestExpectation: Sendable {
  let components: Set<Set<String>>
  let edgeCount: Int
  let totalWeight: Double
}

struct SpanningForestCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let expected: Result<SpanningForestExpectation, GraphError<String>>
}

private func spanningForestComponentSet(_ components: [[String]]) -> Set<Set<String>> {
  Set(components.map { Set($0) })
}

@Suite("Minimum Spanning Forest")
struct SpanningForestTests {
  @Test(
    "Builds minimum spanning forests for undirected graphs",
    arguments: [
      SpanningForestCase(
        name: "chooses the minimum-weight edges and keeps an isolated vertex",
        fixture: GraphFixture(
          directed: false,
          vertices: ["E"],
          edges: [
            TestEdge("A", "B", weight: 10),
            TestEdge("A", "C", weight: 1),
            TestEdge("C", "B", weight: 2),
            TestEdge("B", "D", weight: 4),
            TestEdge("C", "D", weight: 8),
          ]
        ),
        expected: .success(
          SpanningForestExpectation(
            components: [["A", "B", "C", "D"], ["E"]],
            edgeCount: 3,
            totalWeight: 7
          ))
      ),
      SpanningForestCase(
        name: "spans disconnected components independently",
        fixture: GraphFixture(
          directed: false,
          vertices: ["E"],
          edges: [TestEdge("A", "B", weight: 2), TestEdge("C", "D", weight: 1)]
        ),
        expected: .success(
          SpanningForestExpectation(
            components: [["A", "B"], ["C", "D"], ["E"]],
            edgeCount: 2,
            totalWeight: 3
          ))
      ),
      SpanningForestCase(
        name: "empty graph",
        fixture: GraphFixture(directed: false),
        expected: .success(SpanningForestExpectation(components: [], edgeCount: 0, totalWeight: 0))
      ),
      SpanningForestCase(
        name: "negative self-loop does not enter the forest",
        fixture: GraphFixture(directed: false, edges: [TestEdge("A", "A", weight: -1)]),
        expected: .success(
          SpanningForestExpectation(components: [["A"]], edgeCount: 0, totalWeight: 0))
      ),
      SpanningForestCase(
        name: "requires undirected graph",
        fixture: GraphFixture(directed: true),
        expected: .failure(.undirectedGraphRequired)
      ),
    ])
  func minimumSpanningForest(_ testCase: SpanningForestCase) throws {
    let graph = try makeGraph(testCase.fixture)
    switch testCase.expected {
    case .success(let expected):
      let forest = try graph.minimumSpanningForest()
      #expect(
        Set(forest.allVertices())
          == Set(testCase.fixture.vertices).union(
            testCase.fixture.edges.flatMap { [$0.from, $0.to] }), Comment(rawValue: testCase.name))
      #expect(forest.edgeCount == expected.edgeCount, Comment(rawValue: testCase.name))
      #expect(
        spanningForestComponentSet(try forest.connectedComponents()) == expected.components,
        Comment(rawValue: testCase.name)
      )
      #expect(
        forest.allEdges().reduce(0) { $0 + $1.weight } == expected.totalWeight,
        Comment(rawValue: testCase.name))
    case .failure(let error):
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        try graph.minimumSpanningForest()
      }
    }
  }
}
