# ``GraphKit``

GraphKit is a Swift library for creating and analyzing directed and undirected
weighted graphs.

## Overview

Create a graph by choosing whether its edges are directed. Adding an edge also
adds its endpoint vertices if they do not already exist.

```swift
import GraphKit

var graph = Graph<String>(directed: true)
try graph.addEdge(from: "A", to: "B", weight: 4)
try graph.addEdge(from: "A", to: "C", weight: 2)
try graph.addEdge(from: "C", to: "B", weight: 1)

let path = try graph.shortestPath(from: "A", to: "B")
```

GraphKit includes depth-first and breadth-first traversal, hop-distance
neighborhood queries, connected-component and cycle analysis, topological
sorting, minimum spanning forests, and shortest-path algorithms. Shortest-path
results include routes and distances; unreachable vertices have an infinite
distance and no path.

## Topics

### Graphs

- ``Graph``
- ``Direction``
- ``GraphError``

### Traversal and neighborhoods

- ``Graph/depthFirstSearch(from:direction:)``
- ``Graph/depthFirstVisit(from:direction:visitor:)``
- ``Graph/breadthFirstSearch(from:direction:)``
- ``Graph/breadthFirstVisit(from:direction:visitor:)``
- ``Graph/neighborhood(of:maximumDistance:minimumDistance:direction:)``

### Components and topology

- ``Graph/connectedComponent(containing:)``
- ``Graph/connectedComponents()``
- ``Graph/weaklyConnectedComponents()``
- ``Graph/stronglyConnectedComponents()``
- ``Graph/hasCycle()``
- ``Graph/topologicalSort()``

### Shortest paths

- ``ShortestPathResult``
- ``Graph/dijkstra(from:)``
- ``Graph/bellmanFord(from:)``
- ``Graph/floydWarshall()``
- ``Graph/aStar(from:to:heuristic:)``
- ``Graph/breadthFirstShortestPaths(from:)``
- ``Graph/shortestPath(from:to:)``
- ``Graph/shortestDistance(from:to:)``

### Spanning forests

- ``Graph/minimumSpanningForest()``
