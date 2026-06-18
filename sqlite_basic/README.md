# sqlite_basic

SQLite CRUD demonstration in MVL — shows typed queries, row decoding, and full create/read/update/delete operations with a single `User` table.

---

## What this demonstrates

| Concept | Syntax | Purpose |
|---------|--------|---------|
| Typed parameters | `DbValue::Int(1)`, `DbValue::Text("Alice")` | Type-safe SQL bindings |
| Row decoder | `row_to_user(row)` | `Map[String, DbValue]` → domain type |
| Refinement types | `min_age: Int where min_age >= 0` | Compiler-checked domain constraints |
| Totality | `total fn row_to_user`, `total fn collect_users` | Proven-terminating pure functions |
| Error handling | `Result[T, SqliteError]` | All DB errors made explicit |
| Effects | `! DB + FileRead + FileWrite` | Effect annotations on every function |
| CRUD pattern | insert → list → get → update → delete → count | Complete lifecycle |

---

## Project structure

```
sqlite_basic/
├── main.mvl        # Entry point — exercises every CRUD operation
├── models.mvl      # User and CreateUserRequest types with refinements
├── db.mvl          # Database layer: open, init, CRUD, row decoder
├── db_test.mvl     # Unit tests for row_to_user pure logic (14 tests)
├── main_test.mvl   # Unit tests for DbValue / SqliteError enums (18 tests)
├── mvl.toml        # Package manifest
└── mvl.lock        # Pinned dependency versions
```

---

## Quick start

```bash
# Run the demonstration (uses an in-memory database)
make run

# Run unit tests
make test

# Type-check source files
make check

# Full assurance report (check + tests + requirements)
make assurance-verbose
```

---

## Expected output

```
Inserting users...
  inserted id=1 name=Alice
  inserted id=2 name=Bob
  inserted id=3 name=Carol

All users:
  id=1 name=Alice age=30
  id=2 name=Bob age=25
  id=3 name=Carol age=35

Get user id=1:
  Alice, age 30

Users aged 26 or older:
  Alice (30)
  Carol (35)

Update Alice's age to 31:
  updated
  Alice now age=31

Delete Bob (id=2):
  deleted

Final state:
  2 user(s) remaining
  id=1 name=Alice age=31
  id=3 name=Carol age=35
```

---

## Key patterns

### Row decoder with refinement guards

`row_to_user` converts a raw `Map[String, DbValue]` into a typed `User`, enforcing refinement invariants (`id > 0`, non-empty `name`, `age >= 0`) at the boundary:

```mvl
total fn row_to_user(row: Map[String, DbValue]) -> Option[User] {
    match row.get("id") {
        Some(DbValue::Int(id)) => {
            if id <= 0 { None } else {
                match row.get("name") { ... }
            }
        },
        _ => None,
    }
}
```

### Parameterised queries

All SQL parameters use `DbValue` — no string interpolation, no injection risk:

```mvl
execute(db, "INSERT INTO users (name, age) VALUES (?, ?)",
    [DbValue::Text(req.name), DbValue::Int(req.age)])
```

### Refined filter

`query_by_min_age` carries a refinement on its parameter — the compiler proves every call site satisfies `min_age >= 0`:

```mvl
pub partial fn db_list_older_than(val db: SqliteDb, min_age: Int where min_age >= 0) -> ...
```

---

## Assurance

```
Requirements verified:  10 proven, 0 violated  (REQ11 IFC not exercised — no security labels)
  REQ1  Type safety      ✓
  REQ2  Memory safety    ✓
  REQ3  Totality         ✓  row_to_user and collect_users explicitly total
  REQ4  Null elimination ✓  no direct Option access
  REQ5  Error visibility ✓  all Result values handled
  REQ6  Ownership        ✓
  REQ7  Effects          ✓  all effects declared
  REQ8  Termination      ✓
  REQ9  Data race freedom✓
  REQ10 Refinements      ✓  3 call sites, all statically proven (L1 trivial)
```

---

## License

Apache-2.0 — see [LICENSE](LICENSE).
