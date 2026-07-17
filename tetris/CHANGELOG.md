# Changelog

All notable changes to tetris will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
