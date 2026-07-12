# pong

Terminal Pong — the classic paddle-and-ball game.  Demonstrates **all 11
MVL requirements** with heavy prover load, built on `pkg-tui` for raw
terminal control.

---

## Quick start

```bash
make run                                                 # interactive menu → play
make run ARGS="--mode single --palette color --difficulty medium"    # skip menu
make all                                                 # full quality gate
```

Controls in game:
- Left player: `w` (up) / `s` (down)
- Right player: `↑` / `↓` (TwoPlayer mode only)
- Quit: `q` or `Esc`

---

## What this demonstrates

Every MVL requirement is exercised.  See `requirements.md §5` for the full
mapping table.

| Req | Concept | How pong exercises it |
|---|---|---|
| 1  | Type Safety | ADT for every domain concept — `Ball`, `Paddle`, `Field`, `Game`, `Mode`, `Palette`, `Difficulty`, `Side`, `GameStatus`, `PaddleInput` |
| 3  | Exhaustiveness | Every `match` on a game enum covers every arm — no `_` wildcards in the pure core |
| 4  | Null Elimination | `Option[PaddleInput]` for "no input this tick"; no bare `unwrap` |
| 5  | Error Visibility | `new_terminal()` returns `Result`; CLI parse returns `Result[Config, String]` |
| 7  | Effect Tracking | `models.mvl` / `game.mvl` / `input.mvl` = zero effects; `main.mvl` = `! Terminal + Random + Console + Env` |
| 8  | Termination | Every pure fn is `total fn` — no recursion in the physics |
| 10 | Refinements + Contracts | ~30 explicit `requires`/`ensures` obligations + refinements at every construction site |
| 11 | Information Flow | `LeftInput` / `RightInput` labels partition paddle-move inputs — a compile-time guarantee that a left key can never move the right paddle (§16) |

---

## Module structure

Mirrors `crud_api`: types / logic / I/O split into their own files with paired
`_test.mvl` files.

| File | Effects | Purpose |
|------|---------|---------|
| `models.mvl`      | *(none)* | Types with refinements + Paddle `with invariant` |
| `game.mvl`        | *(none)* | Pure game logic (all `total fn`); IFC labels + dispatch |
| `input.mvl`       | *(none)* | `pkg.tui.Key → Option[PaddleInput]` (per player side) |
| `main.mvl`        | `! Terminal + Random + Console + Env` | Menu, CLI parse, game loop, rendering |
| `models_test.mvl` | *(none)* | 16 constructor + invariant tests |
| `game_test.mvl`   | *(none)* | 30 physics / bounce / scoring / win tests |
| `input_test.mvl`  | *(none)* | 15 key-mapping tests |

---

## The prover does real work

`game.mvl` carries ~30 explicit contract obligations that the Z3 solver
discharges at compile time.  Highlights from `requirements.md §7`:

- `step_ball` — precondition ball is in-field, postcondition it stays in-field
- `bounce_wall` — flips `vy` at edges, preserves magnitude
- `bounce_paddle` — flips `vx`, preserves `y` and `vy`
- `resolve_scoring` — score monotonically non-decreasing; ≤1 point per call
- `speed_step_up` — velocity magnitude ≤ 3 (cap) for every difficulty

Run `mvl prove .` to see the per-obligation breakdown.

---

## Play modes and options

- **Mode** — `SinglePlayer` (human vs AI) or `TwoPlayer` (both sides human)
- **Palette** — `BlackWhite` (mono) or `Color` (Cyan/Magenta paddles, Yellow ball)
- **Difficulty** — `Simple` (constant speed), `Medium` (+1 |vx| every 3 paddle
  bounces), `Hard` (+1 |vx| after each rally win, applied in `resolve_scoring`)
- **Winning score** — hard-coded to 11.  The `Config.winning_score` field is
  refined `[1..21]` so the check_win contract discharges for any future range.

---

## Menu

Startup opens the menu unless all three CLI flags are provided.  Arrow keys
navigate rows and cycle values; Enter starts the game; Esc quits.

```
╔══════════════════════════════════╗
║           M V L   P O N G        ║
╠══════════════════════════════════╣
║  ▶ Mode:       Single            ║
║    Palette:    Color             ║
║    Difficulty: Medium            ║
║                                  ║
║  ↑↓ move · ← → cycle · ⏎ start   ║
╚══════════════════════════════════╝
```

---

## Effect boundary check

```bash
grep '!' models.mvl game.mvl input.mvl
# (no output — pure files)

grep -n '!' main.mvl | grep 'fn.*!'
# fn main() -> Unit ! Terminal + Random + Console + Env
# ...and every helper that touches the terminal.
```

Reader can see at a glance where I/O lives — nowhere else in the codebase.

---

## Compiler feedback filed during development

Four issues were opened and fixed / worked around while building this example:

- [#1777](https://github.com/mvl-lang/mvl/issues/1777) — parser rejected unary
  minus in refinement predicates.  **Fixed in 0.246.2.**
- [#1780](https://github.com/mvl-lang/mvl/issues/1780) — cross-file IFC labels
  lost their `[T]` type argument.  **Fixed in 0.247.1.**  Still incomplete
  for `let` annotations — see [#1784](https://github.com/mvl-lang/mvl/issues/1784).
- [#1781](https://github.com/mvl-lang/mvl/issues/1781) — refined-type aliases
  behaved nominally at struct construction.  **Fixed in 0.247.2.**  Comparison
  sites still require the same nominal type on both sides — see referenced
  issues.
- [#1784](https://github.com/mvl-lang/mvl/issues/1784) — labeled type on `let`
  annotation cross-file differs from RHS type.  Open.

Consequence in the shipped code:
- `FieldCol` / `FieldRow` position aliases would DRY the shared `120`/`40`
  bounds, but require comparison-site widening (per #1781 follow-up).  Inline
  refinements kept.
- `LeftInput` / `RightInput` labels + relabels are colocated in `game.mvl`
  (not `models.mvl` where the design would put them) — per #1784.  The IFC
  guarantee still holds inside `game.mvl`.

---

## Original spec

> Ok in ~/wc/mvl-lang/examples can you add the game of pong? Just the classic
> version with two modes: single player, dual player. Get inspiration from
> snake_game to use pkg-tui. add black and white mode and color mode. I think
> it can live in one file and I know a typescript version is about 200 lines.
> Give me the requirements first. Follow the file structure of crud_api and
> be sure that all 11 requirements are met. I also want the prover to have
> many many proves for correctness

Follow-up refinements to the spec:

- Field size maximized to terminal geometry (clamped to `[20..120] × [10..40]`)
- Winning score hard-coded to 11
- Three difficulty levels (Simple / Medium / Hard) with distinct ball-speed policies
- Opening menu, or `--mode` / `--palette` / `--difficulty` CLI to skip
- `requirements.md` documents everything (§1–16)
- `make assurance` / `make coverage` / `make mcdc` targets alongside the standard ones
- IFC labels lift Req 11 from "trivially satisfied" to actively enforced

See `requirements.md` for the full spec.

---

## Related

- `snake_game` — the effect-boundary example this inspired  
- `crud_api` — the file-layout convention this follows
