import Testing

@testable import GraphKit

struct TopologicalSortCase: Sendable {
  let name: String
  let fixture: GraphFixture
  let expected: Result<Set<String>?, GraphError<String>>
}

@Suite("Topological Sort")
struct TopologicalSortTests {
  @Test(
    "Returns valid orders for DAGs and nil for cycles",
    arguments: [
      TopologicalSortCase(
        name: "chain has one valid ordering",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B"), TestEdge("B", "C")]),
        expected: .success(["A", "B", "C"])
      ),
      TopologicalSortCase(
        name: "branching and disconnected DAG includes isolated vertices",
        fixture: GraphFixture(
          directed: true,
          vertices: ["D"],
          edges: [TestEdge("A", "B"), TestEdge("A", "C")]
        ),
        expected: .success(["A", "B", "C", "D"])
      ),
      TopologicalSortCase(
        name: "empty graph",
        fixture: GraphFixture(directed: true),
        expected: .success([])
      ),
      TopologicalSortCase(
        name: "directed cycle has no topological ordering",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "B"), TestEdge("B", "A")]),
        expected: .success(nil)
      ),
      TopologicalSortCase(
        name: "self-loop has no topological ordering",
        fixture: GraphFixture(directed: true, edges: [TestEdge("A", "A")]),
        expected: .success(nil)
      ),
      TopologicalSortCase(
        name: "requires directed graph",
        fixture: GraphFixture(directed: false),
        expected: .failure(.undirectedGraphRequired)
      ),
    ])
  func sortsDirectedAcyclicGraphs(_ testCase: TopologicalSortCase) throws {
    let graph = try makeGraph(testCase.fixture)
    switch testCase.expected {
    case .success(let expectedVertices):
      let result = try graph.topologicalSort()
      if let expectedVertices {
        #expect(result.map(Set.init) == expectedVertices, Comment(rawValue: testCase.name))
        if let result {
          let positions = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($1, $0) })
          let allEdgesAppearInOrder = testCase.fixture.edges.allSatisfy { edge in
            guard let from = positions[edge.from], let to = positions[edge.to] else {
              return false
            }
            return from < to
          }
          #expect(allEdgesAppearInOrder, Comment(rawValue: testCase.name))
        }
      } else {
        #expect(result == nil, Comment(rawValue: testCase.name))
      }
    case .failure(let error):
      #expect(throws: error, Comment(rawValue: testCase.name)) {
        try graph.topologicalSort()
      }
    }
  }
}
