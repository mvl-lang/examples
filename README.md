# MVL Examples

Example projects demonstrating MVL's compile-time verification features.

## Examples

| Example | Description | Requirements Demonstrated |
|---------|-------------|---------------------------|
| [crud_api](./crud_api/) | REST API over SQLite | Effects, IFC, Refinements, Config |
| [sqlite_basic](./sqlite_basic/) | SQLite CRUD — insert, query, update, delete | Typed queries, Refinements, Totality |
| [zmq_hello](./zmq_hello/) | ZMTP 3.x wire protocol — pure-MVL ZeroMQ | Effects, TCP networking, cross-language |

## Getting Started

Each example is a standalone MVL project. To run:

```bash
cd crud_api
mvl run main.mvl
```

## Package Dependencies

Examples use packages from the [mvl-lang](https://github.com/mvl-lang) organization:

| Package | Description |
|---------|-------------|
| [pkg-http](https://github.com/mvl-lang/pkg-http) | HTTP types, routing, REST helpers |
| [pkg-sqlite](https://github.com/mvl-lang/pkg-sqlite) | SQLite database driver |
| [pkg-anthropic](https://github.com/mvl-lang/pkg-anthropic) | Claude API client |
| [pkg-rest](https://github.com/mvl-lang/pkg-rest) | REST client over TLS |
| [pkg-tls](https://github.com/mvl-lang/pkg-tls) | TLS 1.3 client |
| [pkg-tui](https://github.com/mvl-lang/pkg-tui) | Terminal UI |
| [pkg-zmq](https://github.com/mvl-lang/pkg-zmq) | ZeroMQ-style messaging |

## Related

- [MVL Language](https://github.com/LAB271/mvl_language) — Compiler
- [mvl-lang.org](https://mvl-lang.org) — Documentation
