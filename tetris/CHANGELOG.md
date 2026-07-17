# Changelog

All notable changes to tetris will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
