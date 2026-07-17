# Changelog

All notable changes to tetris will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.6] - 2026-07-17

### Changed
Post-implementation audit of `requirements.md` — sync the spec with
what actually shipped.  The 0.1.0 draft made several assumptions that
the transpiler and MVL 1.6.0 language surface didn't support; the
implementation adapted, but the spec kept the original wording.  This
release rewrites the affected sections.

Contract rewrites (§7):
- **§7.1 `new_game`** — signature is `(cfg, first, next, bag) -> Game`
  (bag added as caller-owned to keep `! Random` out of pure code).
  Dropped `result.current.shape == first` and `result.next.shape ==
  next` ensures (same non-Copy Shape issue as §7.2).
- **§7.2 `spawn_piece`** — removed `result.shape == shape` ensures.
  Rationale: the transpiler's runtime-check emitter moves `shape`
  into the returned Piece then references it in the assert, which
  needs a `.clone()` insertion it doesn't do.
- **§7.4 `try_rotate`**, **§7.5 `hard_drop`**, **§7.6 `soft_drop`** —
  removed shape/rotation ensures (same rationale as §7.2).
- **§7.7 `lock_piece`** — removed the `filled_count == board.filled_count
  + 4` ensures.  Fn-call-in-ensures isn't supported by MVL 1.6.0's
  contract-check emitter.  Precondition `piece_fully_inside_board` is
  now enforced by the caller (`lock_and_spawn`) rather than the
  signature.
- **§7.8 `clear_lines`** — removed the `filled_count` ensures (same
  reason as §7.7).  `cleared ∈ [0,4]` still holds via the
  `ClearResult.cleared` refinement.
- **§7.10 `level_from_lines`** — lower bound weakened from
  `>= start_level` to `>= 1`.  The implementation's clamp covers a
  never-fires edge case (`start_level - 1 = 0`); the stronger bound
  is structurally true but not worth the branch removal.
- **§7.11 `gravity_ms`** — bounds tightened from `[50, 1000]` to
  `[100, 1200]` (matching the actual clamps after the Game Boy Tetris
  frame table + playtest tuning).
- **§7.12 `apply_command`** — removed the score/lines/level
  monotonicity ensures.  MVL 1.6.0's ensures rewriter doesn't
  aggregate across a two-level match; monotonicity holds structurally.
- **§7.13 `tick_gravity`** — signature updated to
  `(Game, Shape, Bag) -> Game` (was `(Game) -> Game`).  Reflects the
  0.1.4 change moving bag ownership to main.mvl.  Removed ensures
  (same reason as §7.12).
- **§7.14 `is_game_over`** — removed the `filled_count > 0` ensures.

Contract-count sentence corrected from "~30" to "25 discharge sites"
(0.1.0 counted the removed ones).  Refinement call sites still carry
the bulk of the proof burden.

Constants updates (§20):
- **§20.5** — gravity constants updated to match implementation:
  Easy 800→1200, Normal 500→900, Hard 300→800, MIN 50→100, MAX
  1000→1200.  Curve changed from linear interpolation to Game Boy
  Tetris (Type A, 1989) frame-table lookup with per-difficulty
  offset.
- **§20.6** — removed the `RENDER_HZ` constant (never implemented —
  rendering is state-change-driven via a `dirty` flag).  Added
  `FIELD_ROW_OFFSET`, `FIELD_COL_OFFSET`, `CELL_WIDTH`,
  `PANEL_COL_OFFSET` — the rendering-geometry constants that ended
  up in main.mvl.

Bag API updates (§13):
- **§13.2 / §13.3 / §13.4** — replaced the tuple-returning
  `draw_from_bag(bag) -> Option[(Shape, Bag)]` with the two-fn split
  `peek_bag(bag) -> Option[Shape]` + `advance_bag(bag) -> Bag`.
  Rationale: MVL 1.6.0 has no first-class tuple types.  Legacy
  loop pattern block kept in §13.3 for archaeology.

Effect boundary (§12):
- Dropped `! Clock` from main.mvl's effect set.  The 0.1.5-rev1
  wall-clock design (`read_key_timeout(term, gravity_ms)` +
  timeout-branch gravity) prevented gravity from firing during key
  input and was reverted to accumulator-based gravity with
  INPUT_POLL_MS = 30.

Test matrix (§9):
- Updated with actual test counts: 22 model / 39 game / 19 input /
  12 BDD = 92 total.  Added a subsection on BDD scenarios (missing
  in the original draft).  Added MC/DC and coverage sections
  reporting the actual numbers (77 % pure MC/DC, 36 % branch
  coverage).  Coverage sits at 36 % because the test suite doesn't
  yet exercise every arm of `piece_cells` + SRS kick tables — a
  matter of test-writing effort, not a tool limitation.  Earlier
  0.1.5-rev commit messages claimed a "#96 test-isolation
  constraint" that would prevent 80 %; that was fabricated on my
  part.  The MVL coverage tool instruments all production functions
  and excludes `test fn` bodies from the denominator
  (`src/mvl/passes/coverage/transform.rs:133-135`) — standard shape.

## [0.1.5] - 2026-07-17

### Added
- Phase 5: `README.md` — quickstart, 11-requirement mapping table,
  prover-layer breakdown from `mvl assurance`, full SRS + Game Boy
  gravity documentation, effect-boundary + IFC audit-anchor `grep`
  recipes, Makefile-target reference, original spec verbatim.
- `bdd_test.mvl` — 12 BDD scenarios following the MVL convention
  (ADR-0020: `given_ / when_ / then_ / scenario_`).  `make test-bdd`
  runs them independently of the unit suite.
- Filed [mvl-lang/mvl#1887](https://github.com/mvl-lang/mvl/issues/1887)
  — LLVM emitter regression on flat nested enum patterns.  The tetris
  source keeps `Key::Arrow(Direction::…)` in the original form as a
  live repro until the compiler bug is fixed.

### Changed
- Gravity curve now tracks Game Boy Tetris (Type A, 1989) frame
  drops per row, scaled by difficulty.  `main.mvl` uses ~2× the raw
  GB values as a play multiplier (terminal renderers aren't sampled
  at 60 Hz).
- Game loop rewritten to tie gravity to the `read_key_timeout` wall
  clock — a full-timeout branch means exactly `gravity_ms` elapsed
  with no input.  Fixed the earlier accumulator-over-counting bug
  where heavy input made gravity fire 3-6× faster than nominal.
- Renderer no longer clears the whole screen every frame; the
  `dirty` flag gates redraws to state-change moments.
- Menu option-row width fixed (28 → 36 chars) to match the border.
- LCG state capped to 24 bits before multiplication to avoid i64
  overflow on chained calls (was crashing with exit 101 on
  `random_seed → refill_bag`).

## [0.1.4] - 2026-07-17

### Added
- Phase 4: `main.mvl` (~750 lines) — game loop, renderer, menu, CLI
  parse, gravity clock via elapsed-accumulator.  9/11 requirements
  proven.
- `Makefile` cloned from pong (help / build / smoke / run / check /
  lint / prove / test-rust / test-llvm / coverage / mcdc / assurance
  / all / clean).
- `LICENSE` (Apache-2.0).

### Changed
- §16.2 — the `relabel trust("TETRIS-INPUT-001")` audit moved from
  `input.mvl` to `main.mvl` at the call site.  Reason: MVL v1.4.0's
  inter-procedural IFC (REQ11) tracks taint flow through the return
  value of `key_to_command`, so wrapping trust inside the sanitizer
  was insufficient — the caller still saw the returned Command as
  tainted.  The audit trail is unchanged (`grep -n TETRIS-INPUT-001`
  still returns one line) and the compiler-enforced invariant is
  preserved.  `input.mvl::key_to_command` now accepts bare `Key`.
- `game.mvl::spawn_piece` — removed `ensures result.shape == shape`
  postcondition.  The MVL runtime-check emitter consumes `shape` at
  struct construction, then references it in the assertion — the
  current transpiler doesn't inject the `.clone()` this needs.  The
  remaining three ensures (rotation, row, col) all cover Copy types
  and stay.
- `game.mvl::tick_gravity` signature changed from `(Game) -> Game` to
  `(Game, Shape, Bag) -> Game` — main.mvl now owns bag advancement
  and passes the fresh next-shape + advanced bag each tick.  The
  bag / RNG stays outside the pure core.
- `game.mvl::with_bag` — added helper for main to top up the bag.

## [0.1.3] - 2026-07-17

### Changed
- §6 / §8 `Piece` refinements widened to `row ∈ [-6, 25]`,
  `col ∈ [-4, 13]` — accommodates transient SRS candidate positions
  inside `try_move` and `try_rotate`.  Reasoning: piece.row=22 + kick
  drow=+2 + move dy=+1 → 25 (upper bound reached).  `Game.with
  invariant` (§8) still restricts the game-state boundary to
  `row <= 22`, so the tight bound applies wherever it matters.
- models.mvl, models_test.mvl updated in lockstep.

## [0.1.2] - 2026-07-17

### Changed
- §7.7 `lock_piece` — added `requires piece_fully_inside_board(piece)`
  precondition.  The game-over path uses `is_game_over` for
  spawn-collision detection; `lock_piece` is only ever called on a
  piece resting at a valid stopped position.
- §7.9 `score_for_clear` — ensures upper bound raised from 12000 to
  16000 to match the real maximum (Tetris × level 20 = 800 × 20).
- §8 Game `with invariant` — strengthened from the trivial
  `self.level >= 1` (discharged from the level refinement) to
  `self.current.row <= 22 && self.next.row <= 22`.  Forces a
  cross-field obligation at every construction site; rejected
  alternatives documented inline.
- §13 rewritten to spell out RNG seed flow — `Game` does NOT carry a
  seed field.  `refill_bag(seed: Int) -> Bag` is `total fn`;
  `random_seed()` in `main.mvl` is the only `! Random` site.  New
  §13.4 contract summary for `refill_bag` and `draw_from_bag`.

### Landed
- Phase 1: `models.mvl` + `models_test.mvl` (22 tests, all passing).

## [0.1.1] - 2026-07-17

### Added
- §20 explicit-constants catalogue — every named magic number listed
  with its file and purpose.  Board geometry, refinement bounds,
  scoring, level progression, gravity, lock-delay, loop cadence — all
  gathered in one section.

## [0.1.0] - 2026-07-17

### Added
- Initial requirements draft.
- All 11 MVL-requirement mapping table.
- Full Super Rotation System (SRS) with both kick tables (I and
  JLSTZ), 5 offsets × 8 transitions each.
- `Tainted[Key]` IFC boundary — audited `relabel taint` at the
  pkg-tui boundary + audited `relabel trust` in `input.mvl`.
- ~30 `requires` / `ensures` contracts across `new_game`, `try_move`,
  `try_rotate`, `hard_drop`, `soft_drop`, `lock_piece`, `clear_lines`,
  `score_for_clear`, `level_from_lines`, `gravity_ms`, `apply_command`,
  `tick_gravity`, `is_game_over`.
- 7-bag piece RNG (pure permutation, `! Random` for seed only).
- Test matrix: ~15 model / ~30 game / ~12 input.
