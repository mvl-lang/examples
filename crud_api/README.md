# crud_api

Full REST API over SQLite — demonstrates **layered config**, **pkg.http**, **pkg.sqlite**, and **audit logging**.

Inspired by: ["I Ditched FastAPI for Rust"](https://towardsdev.com/i-ditched-fastapi-for-rust-heres-what-no-one-tells-you-b7713b522518) (Aaron Philip, May 2026)

---

## What this demonstrates

| Concept | Syntax | Purpose |
|---------|--------|---------|
| Composite effect | `effect AppIO > DB + Env + FileRead + Log + Audit + Net` | Bundle effects under one name |
| Layered config | defaults → TOML → env vars → CLI args | Production config pattern |
| REST routing | `new_router()`, `route()`, `dispatch()` | pkg.http helpers |
| SQLite operations | `open()`, `execute()`, `query()` | pkg.sqlite typed queries |
| Typed values | `DbValue::Int(1)`, `DbValue::Text("Alice")` | Type-safe SQL parameters |
| Structured logging | `logger.info("action", {"key": "value"})` | std.log with JSON output |
| Audit trail | `auditor.emit(modify(...))` | std.audit compliance records |

---

## Project Structure

Following the separation of concerns from the FastAPI→Rust article:

```
crud_api/
├── main.mvl       # Entry point, router setup, server loop
├── handlers.mvl   # HTTP handlers (request → response)
├── models.mvl     # Data types (User, CreateUserRequest, etc.)
├── db.mvl         # Database operations (CRUD)
├── config.mvl     # Configuration loading
├── seed.mvl       # CSV seeding
├── config.toml    # Default configuration
└── users.csv      # Sample seed data
```

---

## Routes

| Method | Path | Handler | Audit Event |
|--------|------|---------|-------------|
| GET | `/users` | List all users | `access.read` on collection |
| POST | `/users` | Create user | `create.user` mutation |
| GET | `/users/{id}` | Get user by ID | `access.read` on user |
| PUT | `/users/{id}` | Update user | `update.user` mutation |
| DELETE | `/users/{id}` | Delete user | `delete.user` mutation |

---

## Config layering

```
1. Defaults (hardcoded)     → port=8080, db=/tmp/crud_api.db
2. config.toml              → override defaults
3. CRUD_API_* env vars      → override TOML
4. CLI args (--port, --db)  → override env
```

---

## Running

```bash
# Build and run with defaults
make run

# Override port via env
CRUD_API_PORT=9090 make run

# Override via CLI args
make run ARGS="--port 9090 --db-path /tmp/app.db"

# Seed from CSV
make run ARGS="--seed-file users.csv"
```

---

## Testing

```bash
# In another terminal:
curl -s http://127.0.0.1:8080/users | jq .

# Create user
curl -X POST http://127.0.0.1:8080/users \
     -H 'Content-Type: application/json' \
     -d '{"name":"Alice","email":"alice@example.com"}'

# Get user
curl -s http://127.0.0.1:8080/users/1 | jq .

# Update user
curl -X PUT http://127.0.0.1:8080/users/1 \
     -H 'Content-Type: application/json' \
     -d '{"name":"Alice Smith","email":"alice.smith@example.com"}'

# Delete user
curl -X DELETE http://127.0.0.1:8080/users/1
```

---

## Audit Logging

All mutations emit audit events to the configured audit sink (default: `./audit.jsonl`).

Example audit record:
```json
{
  "timestamp": "2026-06-13T10:30:00Z",
  "principal": "api:anonymous",
  "action": "create.user",
  "resource": "user:42",
  "outcome": "success",
  "details": {"email": "alice@example.com"}
}
```

The audit trail is append-only and tamper-evident — suitable for compliance requirements (GDPR, SOC2, etc.).

---

## MVL Requirements Demonstrated

| Req | What | Where |
|-----|------|-------|
| 9 | Effects | `! DB + Log + Audit + Net` tracked in signatures |
| 10 | Refinements | `port > 0 && port < 65536`, `id > 0` |
| 11 | IFC | `Secret[String]` blocked from logs, audit trail allowed |

---

## Related

- [pkg-http](https://github.com/mvl-lang/pkg-http) — HTTP types and REST helpers
- [pkg-sqlite](https://github.com/mvl-lang/pkg-sqlite) — SQLite driver
- Pattern: `.openspec/patterns/001-config.md`
- Issue: #1000
