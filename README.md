# GraphKit

A Swift library for directed and undirected weighted graphs, traversal, graph
analysis, and shortest-path algorithms.

```swift
import GraphKit

var graph = Graph<String>(directed: true)
try graph.addEdge(from: "A", to: "B", weight: 4)
try graph.addEdge(from: "A", to: "C", weight: 2)
try graph.addEdge(from: "C", to: "B", weight: 1)

let path = try graph.shortestPath(from: "A", to: "B") // ["A", "C", "B"]
```

## Documentation

API reference is generated with Swift DocC and published to GitHub Pages by
`.github/workflows/docs.yml` on pushes to `main`.

Generate and preview it locally:

```sh
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target GraphKit \
  --output-path ./docs \
  --transform-for-static-hosting \
  --hosting-base-path GraphKit
```

## Build and test

```sh
swift build
swift test
```
