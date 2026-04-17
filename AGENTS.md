# AGENTS.md

## Commands

```sh
swift build
swift test
```

Generate the DocC site locally (writes to `./docs`):

```sh
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target GraphKit \
  --output-path ./docs \
  --transform-for-static-hosting \
  --hosting-base-path GraphKit
```

## Structure

- `Package.swift` defines the `GraphKit` library, the `GraphKitTests` test
  target, Swift 6 language mode, and the minimum macOS deployment target.
- `Sources/GraphKit/` contains the public graph API and algorithms. Core graph
  operations are in `Graph.swift`; traversal, graph analysis, shortest paths,
  spanning forests, and topological sorting are grouped by feature.
- `Sources/GraphKit/GraphKit.docc/` contains the DocC landing page and API
  overview.
- `Tests/GraphKitTests/` contains Swift Testing suites, with focused files for
  graph operations and each algorithm family.

## Conventions

- Use Swift 6 language mode with `swift-tools-version: 6.3`; the package enables
  `ApproachableConcurrency` for both targets and supports macOS 15 and later.
- Keep public graph APIs concurrency-safe. Vertex types are constrained to
  `Hashable & Sendable`, and public value types should remain `Sendable` where
  appropriate.
- Use Swift Testing (`import Testing`), not XCTest. Group related input cases in
  `@Test(..., arguments: [...])` and use `Sendable` case structs with a `name`
  field to make failures identifiable. Add cases to the relevant table when
  they exercise an existing behavior group; separate tests are appropriate
  for distinct behavior groups.
- Graph data is stored in hash-based collections. Do not rely on the order of
  vertices, edges, neighbors, or algorithm results unless an API explicitly
  guarantees it. Prefer set comparisons or assert required invariants in tests.
- Keep public API documentation in DocC-compatible Swift doc comments and
  update the DocC overview when adding a public feature.
- `swift-docc-plugin` is the package's only dependency and is used to generate
  documentation; avoid adding dependencies for functionality available in the
  standard library or platform SDKs.
