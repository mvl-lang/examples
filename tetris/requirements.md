# MVL Tetris — Requirements

Formal spec for `tetris` (in the `mvl-lang/examples` repo) — the classic
falling-block puzzle, built to demonstrate all 11 MVL requirements with
heavy prover load and full Super Rotation System (SRS) rotation logic.

Version: 0.1.6 (post-implementation audit) — see [CHANGELOG.md](CHANGELOG.md) for history.
Last updated: 2026-07-17

---

## 1. Intent

Build a terminal Tetris that:

1. Uses `pkg.tui` for raw-mode I/O (mirrors `examples/pong` and `examples/snake_game`).
2. Follows the `crud_api` / `pong` file layout convention — types / logic
   / input / shell split into separate files, each with a paired
   `_test.mvl` file.
3. Exercises **all 11 MVL requirements** — the pure core carries ~30
   `requires` / `ensures` contracts and enforces a `Tainted[Key]` audit
   boundary between the TUI and game logic.
4. Ships the full 7-piece tetromino set (I, O, T, S, Z, L, J) and the
   **complete SRS rotation system** with 5-position wall-kick tests.
5. Ships a menu + CLI for palette (BW / Color), difficulty (Easy /
   Normal / Hard), and start level (1..15).
6. Ships classic scoring, ten-line level progression, and a hard-drop
   mechanic.

## 2. Non-goals

- No sound, no smooth animation, no networking.
- No hold-piece / swap feature. (SRS is heavy enough on its own.)
- No T-spin bonus scoring, no back-to-back, no combo counter — score
  awards are purely single/double/triple/tetris.
- No garbage / multiplayer.
- No high-score persistence.
- No config file (`config.toml`), no save/load.
- No `Secret[T]` labels — nothing in Tetris is confidential.
  `Tainted[Key]` IS used, actively enforced at the pkg-tui boundary
  (see §16).

## 3. Play options

### 3.1 Palette
```mvl
pub type Palette = enum {
    BlackWhite,  // monochrome — every shape uses Style::White with a
                 // per-shape fill glyph so pieces stay distinguishable
    Color,       // I=Cyan, O=Yellow, T=Magenta, S=Green, Z=Red,
                 // L=Blue (bright), J=Blue
}
```

### 3.2 Difficulty
```mvl
pub type Difficulty = enum {
    Easy,        // lock delay 500 ms; start gravity 800 ms
    Normal,      // lock delay 300 ms; start gravity 500 ms
    Hard,        // lock delay 150 ms; start gravity 300 ms
}
```

Difficulty affects only lock delay and the *starting* gravity multiplier;
the level curve remains monotone (see §7.10).

### 3.3 Game status
```mvl
pub type GameStatus = enum {
    Playing,
    Paused,
    GameOver,
}
```

### 3.4 Shape and rotation
```mvl
pub type Shape = enum { I, O, T, S, Z, L, J }
pub type Rotation = enum { R0, R90, R180, R270 }
```

## 4. File layout

Sits alongside `pong`, `snake_game`, `crud_api`, etc. in the
`mvl-lang/examples` repo — standalone example, not part of the compiler
tree.

```
tetris/
├── mvl.toml              — package manifest + pkg-tui dep
├── mvl.lock
├── Makefile              — check / prove / test-mvl / mcdc / coverage / assurance / run
├── README.md             — quickstart + original spec verbatim
├── requirements.md       — this file
├── LICENSE               — Apache-2.0
├── models.mvl            — types, refinements, invariants, SRS kick tables (§8, §11)
├── game.mvl              — pure game logic (all `total fn`), contracts (§7)
├── input.mvl             — Tainted[Key] → Command sanitizer (§16)
├── main.mvl              — menu + CLI parse + game loop + rendering (effects)
├── models_test.mvl       — constructor + invariant tests (~15)
├── game_test.mvl         — SRS + physics + scoring + line-clear tests (~30)
└── input_test.mvl        — key mapping tests (~12)
```

## 5. MVL Requirement mapping (all 11 covered)

| # | MVL Requirement | How Tetris exercises it |
|---|---|---|
| 1  | **Type Safety**       | ADT for every domain concept — `Shape`, `Rotation`, `Cell`, `Pos`, `Piece`, `Board`, `Game`, `GameStatus`, `Command`, `Palette`, `Difficulty`, `Bag`. No primitive obsession. |
| 2  | **Memory Safety**     | All value types; no `ref` cycles. `Terminal` is the only owned resource, dropped in `main` via RAII. `Board` is a value type (`List[List[Cell]]` at ~200 cells is fine). |
| 3  | **Exhaustiveness**    | Every `match` on `Shape`, `Rotation`, `Cell`, `Command`, `Palette`, `Difficulty`, `GameStatus` covers every arm — no `_` wildcards in `models.mvl` / `game.mvl`. |
| 4  | **Null Elimination**  | `Option[Piece]` from `try_move` / `try_rotate` (returns `None` on collision). `Option[Command]` for "no key this tick". Zero bare `unwrap()`. Every `Option` / `Result` handled with `match` or `?`. |
| 5  | **Error Visibility**  | `new_terminal()` returns `Result`; propagated via `?` in `main`. CLI parse returns `Result[Config, String]`. |
| 6  | **Ownership**         | `Terminal` is `iso` (from pkg-tui). Game state passed by value; `val` borrows for read-only board access in collision checks. |
| 7  | **Effect Tracking**   | Sharp boundary — `models.mvl`, `game.mvl`, `input.mvl` = zero effects. `main.mvl` = `! Terminal + Random + Console + Env + Clock`. |
| 8  | **Termination**       | Every function in `game.mvl` / `input.mvl` / `models.mvl` marked `total fn`. `clear_lines`, `hard_drop`, and the SRS kick loop use bounded iteration or `total fn` recursion with a `decreases` clause. Game loop marked `partial fn` (user-driven). |
| 9  | **Data Race Freedom** | Single-threaded. No actors, no shared state. Trivially satisfied. |
| 10 | **Refinement & Contracts** | Heavy — see §6 and §7 for the full list. ~30 explicit `requires` / `ensures` obligations. |
| 11 | **Information Flow**  | Actively enforced — `Tainted[Key]` at the pkg-tui boundary; a single audited `relabel trust("TETRIS-INPUT-001")` in `input.mvl` is the only path from a keypress to game state. See §16. |

## 6. Refinement types (Req 10, part 1)

The playfield is fixed at **10 columns × 20 rows** — the classic Tetris
Guideline dimensions. Refinements below encode that, plus a small
buffer above the visible board so pieces can spawn at row `-2` and
wall-kicks can transiently produce out-of-board offsets.

| Type | Refinement | Rationale |
|---|---|---|
| `Pos.row` | `Int where self >= -4 && self <= 22` | Spawn zone (-2..-1) + visible board (0..19) + kick overshoot buffer |
| `Pos.col` | `Int where self >= -2 && self <= 11` | Wall-kick left/right overshoot buffer |
| `Piece.row` | `Int where self >= -6 && self <= 25` | Wider than `Pos` — holds transient SRS candidate positions inside `try_move` / `try_rotate` |
| `Piece.col` | `Int where self >= -4 && self <= 13` | Same rationale for horizontal SRS kicks |
| `Game.score` | `Int where self >= 0 && self <= 999999` | Non-negative, capped at 999 999 (fits 6-digit HUD) |
| `Game.level` | `Int where self >= 1 && self <= 20` | Classic 20-level cap |
| `Game.lines_cleared` | `Int where self >= 0 && self <= 999` | Non-negative, capped for display |
| `Config.start_level` | `Int where self >= 1 && self <= 15` | User-selectable starting level; 15 is the "Marathon start" cap |

## 7. Contracts (Req 10, part 2)

Contracts on the pure functions in `game.mvl`. Every one becomes a
proof obligation for the Z3 solver.

### 7.1 `new_game(cfg, first, next, bag) -> Game`
```mvl
requires cfg.start_level >= 1 && cfg.start_level <= 15
ensures  result.status == GameStatus::Playing
ensures  result.score == 0
ensures  result.lines_cleared == 0
ensures  result.level == cfg.start_level
```

`bag` is the caller-owned 7-bag (see §13); main.mvl draws `first` /
`next` from the bag before calling.  The `result.current.shape ==
first` and `result.next.shape == next` ensures were dropped because
`Shape` is not `Copy` in the transpiler's runtime-assertion
generator (see §7.2 for the analogous constraint on `spawn_piece`).

### 7.2 `spawn_piece(shape) -> Piece`
```mvl
ensures result.rotation == Rotation::R0
ensures result.row == -1
ensures result.col == 4    // center-left of 10-wide board (Tetris Guideline)
```

The `result.shape == shape` postcondition would double-consume the
non-`Copy` `shape` argument in the transpiler's runtime-assertion
lowering (shape is moved into the returned `Piece`, then referenced
again in the assertion).  Enforced structurally instead: the only
assignment to `Piece.shape` in the fn body is `shape:    shape,`.

### 7.3 `try_move(piece, board, dx, dy) -> Option[Piece]`
```mvl
requires dx >= -1 && dx <= 1
requires dy >= 0 && dy <= 1        // no upward moves; use rotation for that
ensures  match result {
             Some(p) => p.shape == piece.shape
                     && p.rotation == piece.rotation
                     && p.col == piece.col + dx
                     && p.row == piece.row + dy,
             None => true,
         }
```

### 7.4 `try_rotate(piece, board, cw) -> Option[Piece]`
```mvl
// cw: Bool.  true = clockwise, false = counter-clockwise.
// Applies SRS wall-kick tests (§11); returns Some(p) at the first
// kick offset that clears the board, or None if all 5 offsets
// collide.  The `bounded while ... decreases (n - i)` loop keeps the
// body total; the SRS table lookup is a pure fn.
//
// No `ensures` clause — the shape/rotation invariants would require
// referencing `piece.shape` after moving `piece` into the candidate
// Piece constructor, which the transpiler's runtime-assertion
// lowering does not support for non-Copy fields.
```

### 7.5 `hard_drop(piece, board) -> Piece`
```mvl
// Drop the piece as far as it can go before it would collide.  The
// `while !stopped && steps < 32 decreases 32 - steps` loop bounds
// the descent at 32 rows (visible playfield is 20; buffer + refined
// bounds fit inside 32).
//
// No `ensures` clause — see §7.4 rationale.  Correctness is
// established by the loop's monotone-descent invariant (each
// iteration either sets `stopped` or moves the piece down one row)
// plus the `try_move` contract in §7.3.
```

### 7.6 `soft_drop(piece, board) -> Piece`
```mvl
// One-row descent if possible; unchanged otherwise.  Body is a
// single `match try_move(piece, board, 0, 1) { Some(p) => p,
// None => piece }` — correctness follows from §7.3.
//
// No `ensures` clause — see §7.4 rationale.
```

### 7.7 `lock_piece(piece, board) -> Board`
```mvl
// Stamps the piece's 4 filled cells into `board`.  The precondition
// asserts every cell of the piece falls inside the visible playfield
// (rows 0..19, cols 0..9) — game.mvl only calls lock_piece after
// try_move / hard_drop has confirmed the piece rests at a valid
// stopped position.  Callers on the game-over path use
// `is_game_over` instead; a spawn collision is detected before
// lock_piece is ever invoked.
//
// Neither `requires piece_fully_inside_board(piece)` nor
// `ensures filled_count(result) == filled_count(board) + 4` sit on
// the fn signature — MVL 1.6.0's contract-check emitter doesn't
// accept fn-call refinements in ensures.  The `filled_count` helper
// is provided as a public fn (used by tests + assurance), and the
// `piece_fully_inside_board` guard is enforced by the caller
// (`tick_gravity_playing` → `lock_and_spawn`).
```

### 7.8 `clear_lines(board) -> ClearResult`
```mvl
// ClearResult = { board: Board, cleared: Int }.  Filters full rows
// out of `board.cells` and pads the top with empty rows to keep the
// total row count at 20.  Cleared count is refined at the type level
// (`cleared: Int where self >= 0 && self <= 4`), so no explicit
// ensures needed.
//
// No fn-call ensures on `filled_count` — see §7.7.
```

### 7.9 `score_for_clear(cleared, level) -> Int`
```mvl
// Guideline single/double/triple/tetris awards, level-scaled.
// Upper bound: cleared == 4 (Tetris) at level == 20 → 800 * 20 = 16000.
requires cleared >= 0 && cleared <= 4
requires level >= 1 && level <= 20
ensures  result >= 0
ensures  result <= 16000
ensures  cleared == 0  implies result == 0
ensures  cleared == 1  implies result == 100 * level
ensures  cleared == 2  implies result == 300 * level
ensures  cleared == 3  implies result == 500 * level
ensures  cleared == 4  implies result == 800 * level
```

### 7.10 `level_from_lines(lines, start_level) -> Int`
```mvl
requires lines >= 0
requires start_level >= 1 && start_level <= 15
ensures  result >= 1
ensures  result <= 20
// Classic: level = start_level + (lines / 10), capped at 20.
```

The lower bound is `>= 1` rather than `>= start_level` because the
implementation clamps the raw computation: `if raw < 1 { 1 }` — the
clamp exists for the tests to cover a "start_level - 1 = 0" edge
case that never fires in real play.  The stronger `>= start_level`
would be true structurally but the branch removal cost isn't worth
it.

### 7.11 `gravity_ms(level, difficulty) -> Int`
```mvl
requires level >= 1 && level <= 20
ensures  result >= 100
ensures  result <= 1200
// Discrete lookup on the Game Boy Tetris (Type A, 1989) frame table;
// difficulty shifts the whole curve (Easy +300, Normal +0, Hard -100).
```

Bounds are `[100, 1200]` (was `[50, 1000]` before the Game Boy table
landed in 0.1.5 / playtest tweaks in 0.1.5-post).  Monotonicity is
inherent to the lookup — no explicit proof clause, but the table
itself is monotone non-increasing in level.

### 7.12 `apply_command(game, cmd) -> Game`
```mvl
// State-machine dispatch on (game.status, cmd).  Exhaustive nested
// match — every combination has an explicit result (no `_`).
// Game.status transitions: Playing may go to Paused or GameOver;
// Paused may return to Playing; GameOver is terminal.
```

No explicit `ensures` — the monotonicity properties (score, lines,
level all non-decreasing) hold structurally because the fn either
delegates to a sub-fn that returns `with_current(game, ...)` (which
preserves score/level/lines) or a status transition that leaves
scalars alone.  A fn-body proof-of-monotonicity ensures clause would
require aggregating results across the two-level match — the
transpiler's ensures rewriter doesn't handle that shape.

### 7.13 `tick_gravity(game, next_shape, updated_bag) -> Game`
```mvl
// If the piece cannot descend, it locks: score and lines may go up
// and the next piece is spawned.  main.mvl precomputes next_shape
// and updated_bag (see §13); on a non-lock tick, both are unused
// so the bag stays put.
```

Signature is `(Game, Shape, Bag) -> Game` — not the original
`(Game) -> Game` in the 0.1.0-0.1.3 spec.  The change lets main.mvl
own bag advancement and `! Random` (see 0.1.4 changelog).  No
explicit `ensures` for the same reason as §7.12.

### 7.14 `is_game_over(board, piece) -> Bool`
```mvl
// True iff `piece` at spawn position collides with occupied cells.
// Body is a single `piece_collides(piece, board)` call — the
// spawn-collision guard.
```

No ensures — the fn just delegates to `piece_collides`, which
already has structural guarantees from the `piece_cells` /
`cell_collides` chain.

**Total explicit `requires` / `ensures` contracts across game.mvl:
25 discharge sites** (down from ~30 in the 0.1.0 draft; several
were rewritten as structural invariants + comments as the
transpiler's ensures-clause emitter's limits became clear during
implementation).  Refinements on struct fields carry the rest of
the proof burden (~240 refinement call sites, 220 proven /
20 runtime-checked per `mvl assurance`).

## 8. Struct invariants (Req 10, part 3)

```mvl
pub type Pos = struct {
    row: Int where self >= -4 && self <= 22,
    col: Int where self >= -2 && self <= 11,
}

pub type Piece = struct {
    shape:    Shape,
    rotation: Rotation,
    row:      Int where self >= -6 && self <= 25,
    col:      Int where self >= -4 && self <= 13,
}

pub type Game = struct {
    board:         Board,
    current:       Piece,
    next:          Piece,
    bag:           Bag,
    score:         Int where self >= 0 && self <= 999999,
    level:         Int where self >= 1 && self <= 20,
    lines_cleared: Int where self >= 0 && self <= 999,
    status:        GameStatus,
    difficulty:    Difficulty,
    palette:       Palette,
} with invariant self.current.row <= 22 && self.next.row <= 22
```

The `Game` invariant asserts that both the currently falling piece and
the previewed next piece stay within the refined `Pos.row` bound.  It's
not trivially discharged from the per-field refinements because the
prover otherwise treats `Piece.row` as an unrelated integer once it
crosses a struct boundary — the compound invariant forces a
cross-field obligation at every `Game { ... }` construction site.

Rejected alternatives:
- `self.level >= 1` — trivially discharged from the level refinement.
- `piece_shape_matches_current(...)` — genuine state coherence but
  requires a helper fn declared before `Game` (chicken-and-egg for
  models.mvl).  Moves to §7 as a contract on `apply_command` instead.

## 9. Test matrix

**Total: 92 tests across four suites** (`make test`), plus 12 BDD
scenarios that also run under `make test-bdd`.

### `models_test.mvl` — 22 tests
- `Pos` / `Piece` / `Offset` at each refinement boundary (6).
- `Shape` all 7 variants exhaustive; `Rotation` all 4 exhaustive; `Cell`
  Empty + per-shape Filled; `GameStatus`, `Command`, `Palette`,
  `Difficulty` all exhaustive.
- `Config.start_level` at 1 / 15 boundaries; `ClearResult.cleared` at
  0 / 4 boundaries.
- `Bag` empty and full-seven construction.

### `game_test.mvl` — 39 tests
Movement, collisions, scoring, level progression, gravity, clear
lines.  Key coverage points:

- `try_move(dx=-1)` blocked by left wall; `(dx=+1)` blocked by right
  wall; `(dy=+1)` blocked by stack and by floor.
- T-piece collision with a stack cell.
- Board helpers (`empty_board`, `set_cell` in-bounds + out-of-bounds
  across all four edges).
- Rotation cycle correctness (`rotate_cw` all four states).
- `score_for_clear` at each cleared × level combination (0..4 clears,
  levels 1/3/5/20).
- `level_from_lines` at 0 / 10 / 200 lines.
- `gravity_ms` at every difficulty × level 1; L20 floor check; level
  monotonicity check on Easy.
- `row_is_full` on empty, full, and short rows.
- `clear_lines` for 0 / 1 (single) / 4 (tetris); gap preservation.

### `input_test.mvl` — 19 tests
Arrow keys → Move/SoftDrop/Noop (4); rotation upper + lower (4);
action keys space/p/P/q/Q/Escape (6); Noop fall-throughs including
Delete, Backspace, Unknown (5).

### `bdd_test.mvl` — 12 scenarios (ADR-0020)
BDD-style using `given_ / when_ / then_ / scenario_` naming.  Threads
state through `TetrisCtx`.  Covers movement, single/tetris scoring,
level-caps, and Game Boy gravity semantics.

### MC/DC targets

Original 0.1.0 draft called for 100 % on the nine key fns.  Post-
implementation reality (`mvl mcdc .`) is **95/122 obligations met
(77 % pure)** with **9 clauses structurally coupled** (`c == "z" ||
c == "Z"` — the two clauses share the same variable, so unique-cause
independence is impossible under pure MC/DC).  Under DO-178C masking
rules (`mvl mcdc . --masking`) the coupled clauses are exempt.
Remaining misses are almost entirely defensive `None` arms after
bounds checks (dead code by construction).

### Coverage targets

**Branch coverage: 167/455 (36 %)**.  Below the 80 % informal target.
The plain reason: `game.mvl`'s `piece_cells` + two SRS kick tables
generate several hundred match arms (7 shapes × 4 rotations, plus 8
transitions × 2 tables), and the test suite doesn't exercise every
arm.  Reaching 80 % is a matter of writing per-arm tests, not a
tool limitation.  Documented rather than chased for the 0.1.6
release.

(The MVL coverage tool instruments all production functions and
excludes `test fn` bodies from the denominator —
`src/mvl/passes/coverage/transform.rs:133-135`.  Standard shape.)

## 10. CLI reference

```
Usage: tetris [OPTIONS]

Options:
  --palette {bw,color}                Visual palette (default: prompt via menu)
  --difficulty {easy,normal,hard}     Lock-delay + start-gravity policy
  --start-level N                     Starting level 1..15 (default: 1)
  -h, --help                          Show this help
```

Behavior:
- All three of `--palette` / `--difficulty` / `--start-level` provided → skip menu.
- Any missing → menu opens pre-filled with defaults (`Color`, `Normal`, `1`).
- Invalid value → error message + non-zero exit.

## 11. SRS wall-kick tables (Req 10, part 4)

Full Super Rotation System. Two tables total: one for the I piece,
one shared by J / L / S / T / Z. O never kicks (its bounding box is
symmetric under rotation).

Each transition tests 5 candidate offsets `(Δcol, Δrow)` in order.
The first offset that produces a collision-free piece wins. If all
five collide, the rotation is rejected (`try_rotate` returns `None`).

Signs follow the Tetris Guideline: `+Δrow` is downward, `+Δcol` is
rightward. MVL rows grow downward (Guideline uses the opposite Y
convention); we invert `Δrow` at table-lookup time.

### 11.1 J / L / S / T / Z kicks

| Transition | Test 1 | Test 2 | Test 3 | Test 4 | Test 5 |
|---|---|---|---|---|---|
| R0 → R90  | (0, 0) | (-1, 0) | (-1, -1) | (0, +2) | (-1, +2) |
| R90 → R0  | (0, 0) | (+1, 0) | (+1, +1) | (0, -2) | (+1, -2) |
| R90 → R180 | (0, 0) | (+1, 0) | (+1, +1) | (0, -2) | (+1, -2) |
| R180 → R90 | (0, 0) | (-1, 0) | (-1, -1) | (0, +2) | (-1, +2) |
| R180 → R270 | (0, 0) | (+1, 0) | (+1, -1) | (0, +2) | (+1, +2) |
| R270 → R180 | (0, 0) | (-1, 0) | (-1, +1) | (0, -2) | (-1, -2) |
| R270 → R0 | (0, 0) | (-1, 0) | (-1, +1) | (0, -2) | (-1, -2) |
| R0 → R270 | (0, 0) | (+1, 0) | (+1, -1) | (0, +2) | (+1, +2) |

### 11.2 I-piece kicks

| Transition | Test 1 | Test 2 | Test 3 | Test 4 | Test 5 |
|---|---|---|---|---|---|
| R0 → R90  | (0, 0) | (-2, 0) | (+1, 0) | (-2, +1) | (+1, -2) |
| R90 → R0  | (0, 0) | (+2, 0) | (-1, 0) | (+2, -1) | (-1, +2) |
| R90 → R180 | (0, 0) | (-1, 0) | (+2, 0) | (-1, -2) | (+2, +1) |
| R180 → R90 | (0, 0) | (+1, 0) | (-2, 0) | (+1, +2) | (-2, -1) |
| R180 → R270 | (0, 0) | (+2, 0) | (-1, 0) | (+2, -1) | (-1, +2) |
| R270 → R180 | (0, 0) | (-2, 0) | (+1, 0) | (-2, +1) | (+1, -2) |
| R270 → R0 | (0, 0) | (+1, 0) | (-2, 0) | (+1, +2) | (-2, -1) |
| R0 → R270 | (0, 0) | (-1, 0) | (+2, 0) | (-1, -2) | (+2, +1) |

Encoded in `models.mvl` as a `total fn kick_offsets(shape, from, to)
-> List[Pos]` returning exactly 5 `Pos` (or 1 for O). Test coverage
exercises every distinct row of both tables.

## 12. Effect boundary

| File | Effects | Rationale |
|---|---|---|
| `models.mvl` | *(none)* | Pure types, refinements, SRS tables |
| `game.mvl` | *(none)* | Pure logic; all `total fn` |
| `input.mvl` | *(none)* | Pure `Tainted[Key] → Command` sanitizer |
| `main.mvl` | `! Terminal + Random + Console + Env` | Menu, loop, rendering, CLI, bag RNG |

This split is the single most important design decision — it keeps
~85 % of the code fully testable without a TTY, and the prover proves
it stays that way because effect annotations propagate.

**No `! Clock` effect.**  Gravity is driven by an `elapsed`
accumulator inside the game loop rather than by wall-clock reads:
each `read_key_timeout(term, INPUT_POLL_MS = 30)` iteration adds
30 ms to `elapsed`, and gravity fires when `elapsed >=
gravity_ms(level, difficulty)`.  Slight over-count during heavy
input is bounded by the small poll interval.  A `! Clock` design was
explored (0.1.5-rev1: `read_key_timeout(term, gravity_ms)` +
timeout-branch gravity) and reverted — it prevented gravity from
firing while the player was pressing keys.

## 13. Piece bag (7-bag RNG)

Following the Tetris Guideline, pieces are drawn from a *7-bag*: each
of the seven shapes appears exactly once per bag of seven draws, in a
uniformly-random order. The bag is refilled and reshuffled when empty.

### 13.1 Types

- `models.mvl` declares `pub type Bag = struct { pieces: List[Shape] }`.
  The list has 0..7 entries; refilling always pushes 7.

### 13.2 Seed flow

The 7-bag needs entropy for the shuffle *permutation*, but the game
state must stay pure so that `apply_command` / `tick_gravity` don't
inherit `! Random`.  We split the two responsibilities cleanly:

- `main.mvl` owns `! Random`.  Each time the current bag is drained,
  `main.mvl` calls `random_seed()` (`! Random`), producing a fresh
  `Int` seed, and hands it to the pure refill.
- `game.mvl` owns the permutation.  `refill_bag(seed: Int) -> Bag` is
  `total fn` — a Fisher–Yates shuffle of `[I, O, T, S, Z, L, J]`
  parameterised by `seed`; identical seeds → identical bags.  The LCG
  step (`lcg_step`) caps its state to 24 bits before multiplying to
  keep the arithmetic inside `i64` — see the 0.1.5 CHANGELOG.
- The bag API splits into two `total fn`s rather than the original
  `draw_from_bag → Option[(Shape, Bag)]` (MVL 1.6.0 has no first-class
  tuple types).  `peek_bag(bag) -> Option[Shape]` returns `None` on
  an empty bag; `advance_bag(bag) -> Bag` drops the first entry
  (no-op on empty).  Callers pair them.

**`Game` does NOT carry a seed field.**  The seed is transient — it
lives just long enough to produce one refill, then is discarded.
Storing a "next_seed" in `Game` would make the whole struct depend on
an externally-controlled value, which is exactly what `! Random`
already models better.

### 13.3 Loop pattern

```mvl
// main.mvl — every gravity tick, top up the bag if empty then hand
// the peeked next-shape + advanced-bag to game.mvl.  main owns Random.
let topped: Game       = ensure_bag(game);        // ! Random inside if empty
let next_shape: Shape  = match peek_bag(topped.bag) {
    Some(s) => s,
    None    => Shape::I,                          // unreachable after ensure_bag
};
let advanced: Bag      = advance_bag(topped.bag);
game = tick_gravity(topped, next_shape, advanced);
```

Original 0.1.0-0.1.3 draft used a `draw_from_bag → Option[(Shape,
Bag)]` API returning a tuple.  MVL 1.6.0 has no first-class tuple
types, so the API was split.  The stub `expect_or_default(...)` in
the original draft was replaced by an `ensure_bag` helper that
refills before the peek, guaranteeing `peek_bag` returns `Some` in
practice.

Legacy loop-pattern block (rejected — kept for spec archaeology):

```mvl
// Original draft (0.1.0-0.1.3), needs tuple types + a fallible API:
let (shape, bag2): (Shape, Bag) = match draw_from_bag(game.bag) {
    Some(pair) => pair,
    None => {
        let seed: Int = random_seed();            // ! Random
        let fresh: Bag = refill_bag(seed);        // pure
        draw_from_bag(fresh).expect_or_default(...)
    }
};
let game2: Game = Game { bag: bag2, next: spawn_piece(shape), ...game };
```

### 13.4 Contract impact (Req 10)

- `refill_bag(seed) -> Bag` — `ensures result.pieces.len() == 7`.
- `peek_bag(bag) -> Option[Shape]` — no ensures; the fn is a thin
  `bag.pieces.first()` wrapper.
- `advance_bag(bag) -> Bag` — `ensures result.pieces.len() ==
  bag.pieces.len() - 1  ||  bag.pieces.len() == 0`.
- No contract references a `seed` field on `Game`; the seed is a
  parameter of `refill_bag` only.

## 14. Rendering

Playfield: 10 columns × 20 rows, each cell is 2 monospace characters
(`██`) wide so the aspect ratio reads square in most terminal fonts.

- **Border:** `╔═╗╚═╝║` box glyphs (White in both palettes).
- **Cells:**
  - `Color` palette — one ANSI foreground per shape (I=Cyan, O=Yellow,
    T=Magenta, S=Green, Z=Red, L=Blue-bright, J=Blue).
  - `BlackWhite` palette — every filled cell renders as `██` but with
    per-shape *glyph* variation to keep pieces distinguishable
    (I=`██`, O=`▓▓`, T=`▒▒`, S=`░░`, Z=`■■`, L=`◼◼`, J=`□□`).
- **Side panel** (right of the field, ~14 columns):
  - `NEXT` label + 4-row preview of the next piece.
  - `SCORE` / `LEVEL` / `LINES` counters, monospace-aligned.
  - Controls hint at the bottom: `←→ move · ↓ soft · ␣ hard · z/x rot · p pause · q quit`.
- **Overlays:**
  - `Paused` → centered `⏸ PAUSED — press p to resume` on a dimmed field.
  - `GameOver` → centered `GAME OVER — final score: N — press any key to exit`.

## 15. Menu wireframe

```
╔══════════════════════════════════════════════╗
║             M V L   T E T R I S              ║
╠══════════════════════════════════════════════╣
║                                              ║
║   Palette:      B/W      [ Color ]           ║
║   Difficulty:  Easy   [ Normal ]  Hard       ║
║   Start level: [ 1 ]                         ║
║                                              ║
║   ↑↓ move · ←→ cycle · ⏎ start · Esc quit    ║
╚══════════════════════════════════════════════╝
```

- `↑` / `↓` — move between rows.
- `←` / `→` — cycle the value in the current row.
- `⏎` — commit and start.
- `Esc` — abort and exit cleanly.

## 16. Information Flow Control (Req 11)

IFC in Tetris is not decorative — it is the compile-time proof that no
external keystroke reaches game state without passing through a single,
audited relabel.

### 16.1 `Tainted[Key]` at the pkg-tui boundary

`pkg.tui.read_key_timeout` returns a bare `Key`. Because the source is
an external, uncontrolled TTY (the user could pipe an automated script
in), `main.mvl` **explicitly re-taints the key at the trust boundary**
and then trusts it via a second audited relabel:

```mvl
// main.mvl — boundary: TTY → Tainted[Key] → bare Key → Command
let raw:     Key          = read_key_timeout(term, 30)?;
let dirty:   Tainted[Key] = relabel taint(raw, "TETRIS-TUI-BOUNDARY");
let trusted: Key          = relabel trust(dirty, "TETRIS-INPUT-001");
let cmd:     Command      = key_to_command(trusted);
```

Rationale: bare `Key` from `pkg.tui` has no IFC guarantee. Wrapping it
at the boundary makes the taint explicit; unwrapping right before the
sanitizer creates a `grep`-able audit trail without requiring a fork
of pkg-tui.

Compared to pong's approach (which deferred `Tainted[Key]` per pong
requirements §18), Tetris opts in — three lines colocated in
`main.mvl` document the entire boundary.

### 16.2 The sanitizer in `input.mvl`

`input.mvl::key_to_command` accepts bare `Key` and returns `Command`
via an exhaustive match on every Key variant — no `_` wildcards, so
adding a variant to `pkg.tui.Key` forces a decision here:

```mvl
// input.mvl — pure total fn; the exhaustive match IS the sanitization
pub total fn key_to_command(k: Key) -> Command {
    match k {
        Key::Arrow(Direction::Left)  => Command::MoveLeft,
        Key::Arrow(Direction::Right) => Command::MoveRight,
        Key::Arrow(Direction::Down)  => Command::SoftDrop,
        Key::Arrow(Direction::Up)    => Command::Noop,        // no rotate on Up
        Key::Char(c)                 => char_to_command(c),
        Key::Escape                  => Command::Quit,
        Key::Enter                   => Command::Noop,
        Key::Backspace               => Command::Noop,
        Key::Delete                  => Command::Noop,
        Key::Unknown                 => Command::Noop,
    }
}
```

The IFC invariant is enforced by the compiler: any caller with a
`Tainted[Key]` in hand must perform an audited `relabel trust` before
it can invoke `key_to_command`.  There is no path from a raw pkg-tui
keystroke to a `Command` without passing through the pair of relabels
in `main.mvl`.

**Note on where the `relabel trust` lives.** The original design
(0.1.0-0.1.3) placed `relabel trust` inside `input.mvl::key_to_command`
with signature `Tainted[Key] -> Command`.  MVL's inter-procedural IFC
(REQ11 in v1.4.0) tracked the taint flow through the return value,
so callers still saw `cmd` as tainted.  0.1.4 moves the trust relabel
to the call site in `main.mvl`; the sanitizer accepts bare `Key`.
The audit trail is unchanged — `grep -n 'TETRIS-INPUT-001'` still
returns exactly one line, and it is still the sole path from raw key
to game command.

### 16.3 Non-goals for IFC in this example

- No `Secret[T]` — nothing in Tetris is confidential.
- No IFC on CLI args — `--difficulty=hard` is validated at parse time
  by a total fn returning a typed enum; taint here would be ceremony.
- No player-partition labels (unlike pong's `LeftInput` / `RightInput`)
  — Tetris is single-player.

### 16.4 Audit points added by IFC

| Site | Count |
|---|---|
| `main.mvl` — `relabel taint("TETRIS-TUI-BOUNDARY")` at the TTY boundary | 1 |
| `main.mvl` — `relabel trust("TETRIS-INPUT-001")` right before `key_to_command` | 1 |

**Total IFC audit points: 2.** Both colocated in `main.mvl::game_loop`
so the boundary reads top-to-bottom in one place.  `make assurance`
reports both as user-defined audit anchors.

## 17. Makefile targets

The `Makefile` exposes the full quality gate as one-word targets, cloned
verbatim from `pong/Makefile` where possible.

| Target | Command | Purpose |
|---|---|---|
| `make check` | `mvl check .` | Type-check + refinement bounds (no proofs) |
| `make prove` | `mvl prove . --verbose` | Discharge every `requires` / `ensures` via Z3 |
| `make test-mvl` | `mvl test .` | Run all `*_test.mvl` unit tests |
| `make coverage` | `mvl test . --coverage` | Branch coverage report |
| `make mcdc` | `mvl mcdc . --verbose` | MC/DC condition coverage report |
| `make assurance` | `mvl assurance . --json` | Full ISPE-style assurance report (11-req roll-up) |
| `make run` | `mvl run main.mvl` | Launch the game (menu, then play) |
| `make all` | `check test-mvl coverage mcdc prove assurance` | Full quality gate — CI-equivalent |

`make all` is the default `.PHONY: all` target. Every commit that
touches this example is expected to pass it locally.

## 18. Definition of done

- `make check` — passes with zero errors.
- `make prove` — every `requires` / `ensures` and every refinement
  discharge succeeds (≥ 30 proof obligations, all Z3-verified).
- `make test-mvl` — all tests pass.
- `make coverage` — ≥ 90 % branch coverage on `game.mvl`, `models.mvl`,
  `input.mvl`.
- `make mcdc` — 100 % coverage on the nine MC/DC targets listed in §9.
- `make assurance` — all 11 MVL requirements reported as satisfied.
- Manual smoke test: `make run` — menu appears; game plays; both
  palettes render correctly; all three difficulties have distinct
  gravity; SRS wall-kicks fire audibly (the I-piece can slide into a
  1-column overhang; the T-piece can pivot into a T-slot); Pause and
  Game-Over overlays display correctly.

## 19. Original spec

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

## 20. Explicit constants

Every "magic number" that appears more than once in the code lives as a
top-level `pub const` in `models.mvl` (dimensions, spawn geometry,
scoring, SRS bookkeeping) or `game.mvl` (gravity / lock-delay policy).
Refinements retain inline literals — the current MVL parser accepts
integer literals in refinement predicates, and future work will lift
that to accept const identifiers (mirrors pong's approach).

### 20.1 Board geometry (`models.mvl`)

```mvl
pub const BOARD_ROWS: Int = 20;         // visible playfield height
pub const BOARD_COLS: Int = 10;         // visible playfield width
pub const SPAWN_ROW:  Int = -1;         // uniform spawn row for all shapes
pub const SPAWN_COL:  Int = 4;          // center-left column (10/2 - 1)
pub const PIECE_CELLS: Int = 4;         // every tetromino has 4 cells
pub const KICK_TESTS: Int = 5;          // SRS kick offsets per rotation
pub const BAG_SIZE:   Int = 7;          // Tetris Guideline 7-bag
```

### 20.2 Refinement bounds (`models.mvl`)

Values used inline in refinement predicates.  Declared as constants so
`grep` finds every use and code review can reason about them, even
though the compiler currently requires the literal at the refinement
site itself.

```mvl
pub const ROW_MIN:  Int = -4;           // spawn zone + kick overshoot
pub const ROW_MAX:  Int = 22;           // visible + kick overshoot
pub const COL_MIN:  Int = -2;
pub const COL_MAX:  Int = 11;
pub const SCORE_CAP: Int = 999999;      // 6-digit HUD
pub const LINES_CAP: Int =    999;
pub const LEVEL_MIN: Int =      1;
pub const LEVEL_MAX: Int =     20;
```

### 20.3 Scoring (`game.mvl`)

Guideline single/double/triple/tetris awards, multiplied by `Game.level`:

```mvl
pub const SCORE_SINGLE: Int = 100;
pub const SCORE_DOUBLE: Int = 300;
pub const SCORE_TRIPLE: Int = 500;
pub const SCORE_TETRIS: Int = 800;
```

### 20.4 Level progression (`game.mvl`)

```mvl
pub const LINES_PER_LEVEL: Int = 10;    // classic 10-lines-per-level
pub const START_LEVEL_MIN: Int =  1;
pub const START_LEVEL_MAX: Int = 15;
```

### 20.5 Gravity + lock-delay policy (`game.mvl`)

```mvl
// Level-1 gravity per difficulty — the values shown on the menu.
// Actual per-level gravity is a Game Boy Tetris (Type A, 1989)
// frame-table lookup — see `gameboy_ms_at_level` in game.mvl.
pub const GRAVITY_MS_EASY:   Int = 1200;
pub const GRAVITY_MS_NORMAL: Int =  900;
pub const GRAVITY_MS_HARD:   Int =  800;

// Floor and ceiling for `gravity_ms`.
pub const GRAVITY_MS_MIN:    Int =  100;
pub const GRAVITY_MS_MAX:    Int = 1200;

// Lock-delay policy — time a resting piece stays before it locks.
pub const LOCK_DELAY_MS_EASY:   Int = 500;
pub const LOCK_DELAY_MS_NORMAL: Int = 300;
pub const LOCK_DELAY_MS_HARD:   Int = 150;
```

`gravity_ms(level, difficulty)` is a discrete lookup on the Game
Boy frame table (13 rows, one per level band) with a per-difficulty
offset (Easy +300, Normal +0, Hard -100).  The §7.11 contract
`result >= 100 && result <= 1200` is discharged from these
constants at the compile-time solver.

Original 0.1.0-0.1.3 draft used a linear interpolation over
`[GRAVITY_MS_EASY..GRAVITY_MS_MIN=50]`; the switch to the GB table
happened in 0.1.5.  Bounds tightened from `[50, 1000]` to
`[100, 1200]` in the same revision (playtest — 50 ms/row = 20
rows/sec was unplayable).

### 20.6 Rendering geometry (`main.mvl`)

```mvl
pub const INPUT_POLL_MS:      Int =  30;   // gravity-accumulator poll rate
pub const FIELD_ROW_OFFSET:   Int =   2;   // playfield top row inside terminal
pub const FIELD_COL_OFFSET:   Int =   4;   // playfield left col inside terminal
pub const CELL_WIDTH:         Int =   2;   // "██" fits square in monospace
pub const PANEL_COL_OFFSET:   Int =  30;   // side-panel origin
```

The `RENDER_HZ` constant in the 0.1.0-0.1.3 draft was never added —
rendering is state-change-driven via a `dirty` flag in the game
loop, not clocked.  The rest of `main.mvl` is I/O; magic strings
(ANSI glyphs, palette labels) stay inline because they aren't
reused.

## 21. Related

- `pong` — pong requirements.md is the direct template for this doc.
- `snake_game` — first pkg-tui example; established the effect-boundary pattern.
- `crud_api` — the file-layout convention this follows.
