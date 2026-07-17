# MVL Tetris — Requirements

Formal spec for `tetris` (in the `mvl-lang/examples` repo) — the classic
falling-block puzzle, built to demonstrate all 11 MVL requirements with
heavy prover load and full Super Rotation System (SRS) rotation logic.

Version: 0.1.1 (draft, pre-implementation)
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
| `Piece.row` | `Int where self >= -4 && self <= 22` | Same as `Pos.row` |
| `Piece.col` | `Int where self >= -2 && self <= 11` | Same as `Pos.col` |
| `Game.score` | `Int where self >= 0 && self <= 999999` | Non-negative, capped at 999 999 (fits 6-digit HUD) |
| `Game.level` | `Int where self >= 1 && self <= 20` | Classic 20-level cap |
| `Game.lines_cleared` | `Int where self >= 0 && self <= 999` | Non-negative, capped for display |
| `Config.start_level` | `Int where self >= 1 && self <= 15` | User-selectable starting level; 15 is the "Marathon start" cap |

## 7. Contracts (Req 10, part 2)

Contracts on the pure functions in `game.mvl`. Every one becomes a
proof obligation for the Z3 solver.

### 7.1 `new_game(cfg, first, next) -> Game`
```mvl
requires cfg.start_level >= 1 && cfg.start_level <= 15
ensures  result.status == GameStatus::Playing
ensures  result.score == 0
ensures  result.lines_cleared == 0
ensures  result.level == cfg.start_level
ensures  result.current.shape == first
ensures  result.next.shape == next
```

### 7.2 `spawn_piece(shape) -> Piece`
```mvl
ensures result.shape == shape
ensures result.rotation == Rotation::R0
ensures result.row == -1
ensures result.col == 4    // center-left of 10-wide board (Tetris Guideline)
```

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

### 7.4 `try_rotate(piece, board, dir) -> Option[Piece]`
```mvl
// dir: Rotation direction (CW or CCW). Applies SRS wall-kick tests
// (§11); returns Some(p) at the first kick offset that clears the
// board, or None if all 5 offsets collide.
ensures  match result {
             Some(p) => p.shape == piece.shape,
             None => true,
         }
```

### 7.5 `hard_drop(piece, board) -> Piece`
```mvl
// Drop the piece as far as it can go before it would collide.
ensures result.shape == piece.shape
ensures result.rotation == piece.rotation
ensures result.col == piece.col
ensures result.row >= piece.row       // monotone down (or unchanged if on floor)
```

### 7.6 `soft_drop(piece, board) -> Piece`
```mvl
// One-row descent if possible; unchanged otherwise.
ensures result.shape == piece.shape
ensures result.rotation == piece.rotation
ensures result.col == piece.col
ensures result.row == piece.row || result.row == piece.row + 1
```

### 7.7 `lock_piece(piece, board) -> Board`
```mvl
// Stamps the piece's 4 filled cells into `board`.
ensures result.filled_count == board.filled_count + 4
```

### 7.8 `clear_lines(board) -> ClearResult`
```mvl
// ClearResult = { board: Board, cleared: Int }
ensures result.cleared >= 0 && result.cleared <= 4
ensures result.board.filled_count == board.filled_count - result.cleared * 10
```

### 7.9 `score_for_clear(cleared, level) -> Int`
```mvl
// Guideline single/double/triple/tetris awards, level-scaled.
requires cleared >= 0 && cleared <= 4
requires level >= 1 && level <= 20
ensures  result >= 0
ensures  result <= 12000                    // max is Tetris (800) * 20 (max level) = 16000... capped 12000 for level 15
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
ensures  result >= start_level
ensures  result <= 20
// Classic: level = start_level + (lines / 10), capped at 20.
```

### 7.11 `gravity_ms(level, difficulty) -> Int`
```mvl
requires level >= 1 && level <= 20
ensures  result >= 50 && result <= 1000
// Monotone: gravity_ms(l+1) <= gravity_ms(l)   (proven pointwise)
```

### 7.12 `apply_command(game, cmd) -> Game`
```mvl
ensures result.score >= game.score
ensures result.lines_cleared >= game.lines_cleared
ensures result.level >= game.level
// Game.status transitions: Playing may go to Paused or GameOver;
// Paused may return to Playing; GameOver is terminal.
```

### 7.13 `tick_gravity(game) -> Game`
```mvl
ensures result.score >= game.score
ensures result.lines_cleared >= game.lines_cleared
ensures result.level >= game.level
// If the piece cannot descend, it locks: score and lines may go up.
```

### 7.14 `is_game_over(board, piece) -> Bool`
```mvl
// True iff `piece` at spawn position collides with occupied cells.
ensures result == true implies board.filled_count > 0
```

**Total explicit `requires` / `ensures` contracts: ~30**, plus refinement
discharges at every literal / construction site.

## 8. Struct invariants (Req 10, part 3)

```mvl
pub type Pos = struct {
    row: Int where self >= -4 && self <= 22,
    col: Int where self >= -2 && self <= 11,
}

pub type Piece = struct {
    shape:    Shape,
    rotation: Rotation,
    row:      Int where self >= -4 && self <= 22,
    col:      Int where self >= -2 && self <= 11,
}

pub type Game = struct {
    board:         Board,
    current:       Piece,
    next:          Piece,
    score:         Int where self >= 0 && self <= 999999,
    level:         Int where self >= 1 && self <= 20,
    lines_cleared: Int where self >= 0 && self <= 999,
    status:        GameStatus,
    difficulty:    Difficulty,
    palette:       Palette,
} with invariant self.level >= 1
```

The `Game` invariant is trivially discharged from the level refinement
but exists to demonstrate the `with invariant` clause per Req 10, part 3.

## 9. Test matrix

### `models_test.mvl` — ~15 tests
- Constructing `Pos` / `Piece` at each refinement boundary succeeds.
- Constructing outside refined range fails (e.g., `row = -5`, `col = 12`).
- Every `Shape` variant round-trips through `piece_cells` (returns 4
  distinct offsets).
- Every `Rotation` variant round-trips.
- Piece spawn position: I, O, T, S, Z, L, J each spawn at `row=-1, col=4`.
- Kick-table lookup returns 5 offsets for I; 5 offsets for J/L/S/T/Z;
  1 (identity) offset for O.

### `game_test.mvl` — ~30 tests
- `new_game` returns Playing, zero score/lines, level = start_level.
- `spawn_piece` centers each shape at col 4.
- `try_move(dx=-1)` blocked by left wall.
- `try_move(dx=+1)` blocked by right wall.
- `try_move(dy=+1)` blocked by occupied cell.
- `try_move(dy=+1)` blocked by floor.
- `try_rotate` at column 4 succeeds without kick for every shape.
- `try_rotate` next to left wall applies SRS +1 col kick.
- `try_rotate` next to right wall applies SRS -1 col kick.
- `try_rotate` I-piece requires I-specific kick table (kick offsets +2/-2).
- `try_rotate` O-piece is a no-op (returns identical piece).
- `try_rotate` blocked in all 5 kick positions returns `None`.
- `hard_drop` drops to floor from open column.
- `hard_drop` stops on stack.
- `soft_drop` descends 1 row.
- `soft_drop` on floor is a no-op.
- `lock_piece` adds exactly 4 filled cells.
- `clear_lines` clears 0 for no full row.
- `clear_lines` clears 1 single line and awards 100 * level.
- `clear_lines` clears 2 (double) awards 300 * level.
- `clear_lines` clears 3 (triple) awards 500 * level.
- `clear_lines` clears 4 (tetris) awards 800 * level.
- `clear_lines` preserves gaps below cleared lines (no floating cells).
- `level_from_lines(0, start=1)` == 1.
- `level_from_lines(10, start=1)` == 2.
- `level_from_lines(200, start=1)` == 20 (capped).
- `gravity_ms` is monotone non-increasing in level.
- `gravity_ms(20)` >= 50.
- `is_game_over` fires when spawn row has occupied cells.
- Full SRS regression: J piece R0→R90 with a right-wall obstacle
  applies the third kick offset.

### `input_test.mvl` — ~12 tests
- Arrow keys → `MoveLeft` / `MoveRight` / `SoftDrop` / (no default up).
- `z` → `RotateCCW`, `x` → `RotateCW`.
- `space` → `HardDrop`.
- `p` → `Pause`.
- `q` / `Escape` → `Quit`.
- Any other char → `Noop`.
- All variants pass through the `Tainted[Key]` audit boundary.

### MC/DC targets
100 % on `try_move`, `try_rotate`, `hard_drop`, `clear_lines`,
`score_for_clear`, `level_from_lines`, `gravity_ms`, `is_game_over`,
`apply_command`.

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
| `main.mvl` | `! Terminal + Random + Console + Env + Clock` | Menu, loop, rendering, CLI, gravity clock, bag RNG |

This split is the single most important design decision — it keeps
~85 % of the code fully testable without a TTY, and the prover proves
it stays that way because effect annotations propagate.

## 13. Piece bag (7-bag RNG)

Following the Tetris Guideline, pieces are drawn from a *7-bag*: each
of the seven shapes appears exactly once per bag of seven draws, in a
uniformly-random order. The bag is refilled and reshuffled when empty.

- `models.mvl` declares `pub type Bag = struct { pieces: List[Shape] }`
  with a refinement `where len(self.pieces) <= 7`.
- `game.mvl` provides `pub total fn draw_from_bag(bag) -> (Shape, Bag)`
  and `pub total fn refill_bag(seed) -> Bag` — the shuffle *permutation*
  is computed purely from the seed; only the seed generation touches
  `! Random` (in `main.mvl`).

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
before handing it to `input.mvl`:

```mvl
// main.mvl — boundary: TTY → Tainted[Key]
let raw:  Key          = read_key_timeout(term, 30)?;
let dirty: Tainted[Key] = relabel taint(raw, "TETRIS-TUI-BOUNDARY");
let cmd:  Command      = key_to_command(dirty);
```

Rationale: bare `Key` from `pkg.tui` has no IFC guarantee. Wrapping it
at the boundary makes the taint explicit and creates a `grep`-able
audit trail for the boundary itself, without requiring a fork of
pkg-tui to re-declare `read_key` as returning `Tainted[Key]`.

Compared to pong's approach (which deferred `Tainted[Key]` per pong
requirements §18), Tetris opts in — the `relabel taint` at the caller
is one line and makes the boundary visible.

### 16.2 The sanitizer in `input.mvl`

`input.mvl` is the *only* function in the codebase that accepts a
`Tainted[Key]` — every other function accepts sanitized types.
Sanitization is a single audited `relabel trust`:

```mvl
// input.mvl — accepts untrusted input, exists to sanitize
pub total fn key_to_command(k: Tainted[Key]) -> Command {
    match relabel trust(k, "TETRIS-INPUT-001") {
        Key::Arrow(Direction::Left)  => Command::MoveLeft,
        Key::Arrow(Direction::Right) => Command::MoveRight,
        Key::Arrow(Direction::Down)  => Command::SoftDrop,
        Key::Arrow(Direction::Up)    => Command::Noop,        // no rotate on Up
        Key::Char(c) => if c == "z" || c == "Z" {
            Command::RotateCCW
        } else if c == "x" || c == "X" {
            Command::RotateCW
        } else if c == " " {
            Command::HardDrop
        } else if c == "p" || c == "P" {
            Command::Pause
        } else if c == "q" || c == "Q" {
            Command::Quit
        } else {
            Command::Noop
        },
        Key::Escape    => Command::Quit,
        Key::Enter     => Command::Noop,
        Key::Backspace => Command::Noop,
        Key::Delete    => Command::Noop,
        Key::Unknown   => Command::Noop,
    }
}
```

Every user-driven state transition is auditable by
`grep -n "relabel trust.*TETRIS-INPUT-001" .` — the compiler proves no
key value reaches game logic without passing through this one function.

### 16.3 Non-goals for IFC in this example

- No `Secret[T]` — nothing in Tetris is confidential.
- No IFC on CLI args — `--difficulty=hard` is validated at parse time
  by a total fn returning a typed enum; taint here would be ceremony.
- No player-partition labels (unlike pong's `LeftInput` / `RightInput`)
  — Tetris is single-player.

### 16.4 Audit points added by IFC

| Site | Count |
|---|---|
| `main.mvl` — one audited `relabel taint("TETRIS-TUI-BOUNDARY")` at the TTY boundary | 1 |
| `input.mvl` — one audited `relabel trust("TETRIS-INPUT-001")` sanitizer | 1 |

**Total IFC audit points: 2.** These roll into the assurance report as
a "Req 11 audit trail" section, and the two tags are the only strings
`make assurance` reports as user-defined audit anchors.

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
// Starting gravity in milliseconds per row, per difficulty.
pub const GRAVITY_MS_EASY:   Int = 800;
pub const GRAVITY_MS_NORMAL: Int = 500;
pub const GRAVITY_MS_HARD:   Int = 300;

// Floor for gravity — even at max level we don't drop below this.
pub const GRAVITY_MS_MIN:    Int =  50;
pub const GRAVITY_MS_MAX:    Int = 1000;

// Lock-delay policy — time a resting piece stays before it locks.
pub const LOCK_DELAY_MS_EASY:   Int = 500;
pub const LOCK_DELAY_MS_NORMAL: Int = 300;
pub const LOCK_DELAY_MS_HARD:   Int = 150;
```

`gravity_ms(level, difficulty)` interpolates monotonically between the
starting value and `GRAVITY_MS_MIN` across the level range; the
`ensures result >= GRAVITY_MS_MIN && result <= GRAVITY_MS_MAX` contract
in §7.11 is discharged from these constants.

### 20.6 Loop cadence (`main.mvl`)

```mvl
pub const INPUT_POLL_MS: Int =  30;     // key-read timeout per tick
pub const RENDER_HZ:     Int =  30;     // upper bound on redraw rate
```

The rest of `main.mvl` is I/O; magic strings (ANSI glyphs, palette
labels) stay inline because they aren't reused.

## 21. Version history

- **0.1.1** (2026-07-17) — Add §20 explicit-constants catalogue; every
  named magic number listed with its file and purpose.
- **0.1.0** (2026-07-17) — Initial draft.  All 11-requirement mapping,
  full SRS kick tables, `Tainted[Key]` IFC boundary, ~30 contracts.

## 22. Related

- `pong` — pong requirements.md is the direct template for this doc.
- `snake_game` — first pkg-tui example; established the effect-boundary pattern.
- `crud_api` — the file-layout convention this follows.
