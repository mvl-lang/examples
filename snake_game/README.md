# snake_game

Terminal snake game — demonstrates **Req 7 sharp effect boundary** with pure
game logic, built on `pkg-tui` for raw terminal control.

---

## What this demonstrates

| Concept | Syntax | Purpose |
|---------|--------|---------|
| Effect separation | `game.mvl` = pure, `main.mvl` = `! Terminal + Random + Console` | Testable core |
| Terminal effect | `! Terminal` | Raw TUI control (distinct from Console) |
| Option handling | `Option[Dir]` | No key press on some ticks |
| Trust boundary | `pkg-tui` | Lifecycle, key reads, ANSI styling — no in-tree FFI |

---

## Module structure

| File | Effects | Purpose |
|------|---------|---------|
| `game.mvl` | None | Pure game state transitions, refinement-typed Board |
| `input.mvl` | None | `pkg.tui.Key` → game `Dir` mapping (pure) |
| `main.mvl` | `! Terminal + Random + Console` | Game loop, rendering, random food |

`render` lives in `main.mvl` rather than its own file. Splitting it across
files exposes a transpiler quirk where cross-file calls of cross-package
value types (`pkg.tui.Terminal`) emit broken borrows. Keeping all terminal
calls in one file sidesteps it.

---

## Naming: `game::Dir` vs `pkg.tui::Direction`

Both `game` and `pkg.tui` originally exported a type called `Direction`. To
avoid a use-clash, the game module's enum is named `Dir` here. `input.mvl`
imports both and maps between them.

---

## Running

```bash
make run             # play (arrow keys to move, q to quit)
make check           # type-check
make test            # unit tests (game + input)
make smoke           # build-only check (no tty)
make prove           # refinement proofs
make assurance       # assurance report
```

---

## Effect boundary check

```bash
grep '!' game.mvl
# (no output — pure file)

grep '!' main.mvl
# fn main() -> Unit ! Terminal + Random + Console
```

---

## Game loop

```
loop:
  1. read_key_timeout(term, 275ms) → Option[Key]
  2. classify: quit? direction?
  3. apply_update(game, direction, next_food) → Game (pure)
  4. render(term, game) ! Terminal
  5. if !alive → break, else continue
```

---

## Related

- mvl-lang/mvl#1480 — original move ticket (snake_game kept its in-tree, std-only bridge there)
- pkg-tui — raw mode, key reads, ANSI styles
