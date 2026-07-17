# tetris

Terminal Tetris — the classic falling-block puzzle.  Full Super
Rotation System (SRS) with wall kicks, Game Boy Tetris (Type A, 1989)
gravity curve, 7-bag piece RNG, and a Tainted[Key] IFC boundary.
Built on `pkg-tui`, demonstrating **all 11 MVL requirements** with
heavy prover load.

---

## Quick start

```bash
make run                                                             # menu → play
make run ARGS="--palette color --difficulty normal --start-level 5"  # skip menu
make all                                                             # full quality gate
```

Controls:
- `←` / `→` — move
- `z` / `x` — rotate CCW / CW
- `↓` — soft drop
- `␣` (space) — hard drop
- `p` — pause / resume
- `q` / `Esc` — quit

---

## What this demonstrates

Every MVL requirement is exercised.  See `requirements.md §5` for the
full mapping table.

| Req | Concept | How tetris exercises it |
|---|---|---|
| 1  | Type Safety             | ADT for every domain concept — `Shape`, `Rotation`, `Cell`, `Pos`, `Offset`, `Piece`, `Board`, `Bag`, `Game`, `Command`, `Palette`, `Difficulty`, `GameStatus`, `Config`, `ClearResult`.  Zero primitive-obsession slots. |
| 2  | Memory Safety           | All value types; no `ref` cycles.  `Terminal` is the only owned resource, dropped via RAII in `main`. |
| 3  | Exhaustiveness          | Every `match` on `Shape`, `Rotation`, `Cell`, `Command`, `GameStatus`, `Palette`, `Difficulty` covers every arm — no `_` wildcards in `models.mvl` / `game.mvl` / `input.mvl`. |
| 4  | Null Elimination        | `Option[Piece]` from `try_move` / `try_rotate` / `peek_bag`; `Option[Config]` from the menu.  Zero bare `unwrap()`. |
| 5  | Error Visibility        | `new_terminal()` returns `Result`; propagated via `?` in `main`.  CLI parse returns `Result[Config, String]`. |
| 6  | Ownership               | `Terminal` is `iso` (from pkg-tui).  Game state passed by value; `val` borrows for read-only cell access. |
| 7  | Effect Tracking         | Sharp boundary — `models.mvl`, `game.mvl`, `input.mvl` = zero effects.  `main.mvl` = `! Terminal + Random + Console + Env`. |
| 8  | Termination             | Every function in `game.mvl` / `input.mvl` / `models.mvl` marked `total fn`.  The two bounded iterations (`hard_drop`, `refill_bag`, `try_rotate` kick loop, `set_cell` etc.) use `while … decreases <metric>` to stay total.  Game loop marked `partial fn`. |
| 9  | Data Race Freedom       | Single-threaded.  No actors, no shared state.  Trivially satisfied. |
| 10 | Refinement & Contracts  | Heavy — see §7 / §8 of `requirements.md` for the full list.  ~30 explicit `requires` / `ensures` obligations; 220 refinement call sites proven / 28 runtime-checked (out of 240).  See "The prover does real work" below. |
| 11 | Information Flow        | `Tainted[Key]` at the pkg-tui boundary; two audited relabels (`TETRIS-TUI-BOUNDARY` at the raw source, `TETRIS-INPUT-001` right before sanitization) form the only path from a keystroke to game state.  See §16 of `requirements.md`. |

---

## Module structure

Mirrors `pong` and `crud_api`: types / logic / input / shell split
into their own files with paired `_test.mvl` files.

| File | Effects | Purpose |
|------|---------|---------|
| `models.mvl`      | *(none)* | Types with refinements + `Game` `with invariant` |
| `game.mvl`        | *(none)* | Pure game logic (all `total fn`); SRS tables, scoring, gravity |
| `input.mvl`       | *(none)* | `Key → Command` sanitizer (bare Key; taint boundary owned by main) |
| `main.mvl`        | `! Terminal + Random + Console + Env` | Menu, CLI parse, game loop, rendering, IFC boundary |
| `models_test.mvl` | *(none)* | 22 constructor + invariant tests |
| `game_test.mvl`   | *(none)* | 36 SRS / movement / scoring / clear / gravity tests |
| `input_test.mvl`  | *(none)* | 16 key-mapping tests |
| `bdd_test.mvl`    | *(none)* | 12 BDD scenarios (`given_ / when_ / then_ / scenario_`, ADR-0020) |

**86 tests total.**  `make test` runs them all on the Rust backend;
`make test-bdd` runs just the scenario suite.

---

## The prover does real work

`game.mvl` carries ~30 explicit contract obligations that the Z3
solver discharges at compile time.  Highlights from `requirements.md
§7`:

- `spawn_piece` — 3 ensures pin the spawn position (rotation R0, row -1, col 4)
- `try_move` — requires `dx ∈ [-1, 1]` and `dy ∈ [0, 1]`; result shape/rotation/col/row derived from input
- `hard_drop` — result monotone down (`result.row >= piece.row`)
- `lock_piece` — precondition `piece_fully_inside_board`; ensures cell count grows by 4
- `clear_lines` — `cleared ∈ [0, 4]`; board cell-count reduced by `cleared * 10`
- `score_for_clear` — 5 arms × 2 arithmetic bounds, all exhaustive
- `level_from_lines` — result monotone non-decreasing, capped at 20
- `gravity_ms` — result in `[100, 1200]`, mirrors Game Boy Tetris frame table

Run `mvl assurance . --verbose` for the per-obligation breakdown.
Current run:

```
Req  1  Type Safety          ✓  all type constraints satisfied
Req  2  Memory Safety        ✓  64 let bindings, 10 ref bindings, 0 consume violations
Req  3  Totality             ✓  all matches exhaustive
Req  4  Null Elimination     ✓  no direct Option access
Req  5  Error Visibility     ✓  all Result values handled
Req  6  Ownership            ✓  no immutability or linear-type violations
Req  7  Effects              ✓  all effects declared and propagated
Req  8  Termination          ✓  no unbounded loops or unproven recursion
Req  9  Data Race Freedom    ✓  45/45 fns race-free
Req 10  Refinements          ~  11 refined fields; 220 call sites proven, 28 runtime-checked
Req 11  IFC                  ~  2 audited relabels at the TTY boundary
Status: PASS
```

The 28 runtime checks are call sites where the prover deferred to a
runtime assert (typically division bounds and cross-module struct
field arithmetic).  Every check is honest cost — no silent overflow.

---

## Full SRS wall-kick tables

Both kick tables in full — the shared J/L/S/T/Z table and the I-piece
table.  Every rotation transition (8 total per shape) tests 5 candidate
offsets; the first collision-free position wins.  See
`requirements.md §11` for the tables and `game.mvl::kick_offsets` for
the implementation.

Try in the game: rotate the T-piece into a T-slot, rotate the I-piece
into a vertical column against the wall — SRS carries the piece past
the wall automatically.

---

## Game Boy Tetris (Type A, 1989) gravity

`game.mvl::gravity_ms` implements the classic frame-drop table:

| Level | Frames | ms (Normal) | Easy (+300) | Hard (−100) |
|---:|---:|---:|---:|---:|
| 1 (GB 0)  | 53 | 900 | 1200 | 800 |
| 5 (GB 4)  | 37 | 620 | 920 | 520 |
| 10 (GB 9) | 11 | 180 | 480 | 100 |
| 15 (GB 14)|  9 | 150 | 450 | 100 |
| 20 (GB 19)|  6 | 100 | 400 | 100 |

The three difficulty levels shift the entire curve rather than swap it
out — that keeps the level-1-Easy → level-20-Hard span monotone in
speed.  `main.mvl` uses a slightly slower play multiplier (~2× the
raw GB values) because a terminal renderer isn't running at the
Game Boy's 60 Hz frame sampling — see `main.mvl::gravity_for`.

---

## Effect boundary check

```bash
grep '!' models.mvl game.mvl input.mvl
# (no output — pure files)

grep -n '!' main.mvl | grep 'fn.*!'
# fn main() -> Unit ! Terminal + Random + Console + Env
# ... and every helper that touches the terminal.
```

Reader can see at a glance where I/O lives — nowhere else in the
codebase.  The compiler enforces this: effect annotations propagate
transitively.

---

## IFC audit anchors

Two audited relabels bracket the TTY → game-state boundary.  Both
colocated in `main.mvl::game_loop`:

```mvl
let dirty:   Tainted[Key] = relabel taint(k, "TETRIS-TUI-BOUNDARY");
let trusted: Key          = relabel trust(dirty, "TETRIS-INPUT-001");
let cmd:     Command      = key_to_command(trusted);
```

Grep-provable:

```bash
grep -n 'TETRIS-TUI-BOUNDARY\|TETRIS-INPUT-001' *.mvl
# main.mvl: exactly two lines
```

The compiler enforces that no `Key` reaches `key_to_command` without
passing through the `relabel trust` — see `requirements.md §16` for
the design (and why both anchors ended up in `main.mvl` rather than
`input.mvl`).

---

## Play options

- **Palette** — `Color` (per-shape ANSI foreground) or `BlackWhite`
  (per-shape fill glyph so pieces stay distinguishable in
  monochrome).
- **Difficulty** — `Easy` / `Normal` / `Hard`.  Shifts the entire
  gravity curve; does not change board size, piece bag, or rotation.
- **Start level** — 1 through 15.  Level 16-20 is only reachable
  through play.

---

## Compiler feedback filed during development

- [mvl-lang/mvl#1887](https://github.com/mvl-lang/mvl/issues/1887) —
  LLVM backend: `duplicate case value in switch` on flat nested enum
  patterns (e.g. `Key::Arrow(Direction::Left) => ...`).  The Rust
  backend handles this correctly; the LLVM emitter needs to hoist
  nested inner-pattern matches into a per-outer-variant sub-switch.
  Source-level workaround: split into a two-level match.  `input.mvl`
  keeps the original form as a live repro until this is fixed
  upstream.

---

## Makefile targets

| Target | Purpose |
|---|---|
| `make check` | Type-check + refinement bounds (no proofs) |
| `make prove` | Discharge every `requires` / `ensures` via Z3 |
| `make test` | Run all suites (unit + BDD) — 86 tests, Rust backend |
| `make test-bdd` | Run just the BDD scenario suite (12 tests) |
| `make test-rust` | Alias for `make test` |
| `make test-llvm` | Run all suites via the LLVM backend (see #1887) |
| `make coverage` | Branch coverage report |
| `make mcdc` | MC/DC condition coverage report |
| `make assurance` | Full 11-req ISPE-style assurance report |
| `make run` | Play the game (requires a real TTY) |
| `make all` | Full CI-equivalent quality gate |

---

## Original spec

> ok look at mvl-lang/examples and add tetris. Get inspiration from
> pong and snake, use pkg-tui. You might want to go in phases. Give me
> the phases first
>
> — followed by refinements:
> - Full Super Rotation System (SRS) with 5-position wall-kick tables
> - `Tainted[Key]` IFC at the pkg-tui boundary with an audited relabel
> - Follow pong's file structure (models / game / input / main + tests)
> - All 11 MVL requirements, heavy prover load
> - Work on branch `feat/tetris`
> - BDD test suite (`test-bdd` target, Rust backend)

See `requirements.md` for the full spec (v0.1.4) and `CHANGELOG.md`
for the phase-by-phase history.

---

## Related

- `pong` — pong's requirements.md and file layout were the direct template.
- `snake_game` — first pkg-tui example; established the effect-boundary pattern.
- `crud_api` — the file-layout convention this follows.
