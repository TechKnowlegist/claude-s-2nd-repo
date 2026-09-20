# PyCrawl

A complete procedural roguelike dungeon crawler you play in the terminal.
Pure Python standard library — no dependencies required.

```
 ____        ____                    _
|  _ \ _   _/ ___|_ __ __ ___      _| |
| |_) | | | | |   | '__/ _` \ \ /\ / / |
|  __/| |_| | |___| | | (_| |\ V  V /| |
|_|    \__, |\____|_|  \__,_| \_/\_/ |_|
       |___/
```

## Features

- **Procedural dungeons**: every level is a fresh layout of rooms connected
  by corridors, generated from a seed so runs can be reproduced or shared.
- **Field of view**: line-of-sight visibility with a fog-of-war memory of
  rooms you've already explored.
- **Turn-based combat**: attack by walking into monsters; nine monster
  types that get tougher and more varied as you descend, culminating in a
  Dragon boss on the final level.
- **Loot and progression**: potions, scrolls, weapons, armor, and gold;
  gain XP, level up, and grow stronger.
- **Save/load**: quit at any time and continue later.

## Playing

Run it directly, no installation required:

```bash
python3 -m pycrawl
```

Or install it as a proper command:

```bash
pip install -e .
pycrawl
```

Useful flags:

```bash
pycrawl --seed 12345   # play a specific, reproducible dungeon seed
pycrawl --continue     # resume your last saved game
pycrawl --new          # start over, discarding any save
pycrawl --no-color     # disable ANSI colors
```

### Controls

| Command | Action |
|---|---|
| `n` `s` `e` `w` `ne` `nw` `se` `sw` (or `hjkl`+`yubn`) | Move / attack in that direction |
| `g` | Pick up whatever is underfoot |
| `i` | Show inventory |
| `u <#>` | Use an item (drink a potion, read a scroll, equip gear) |
| `e <#>` | Equip a weapon or armor from your inventory |
| `d <#>` | Drop an item |
| `>` | Descend the stairs (must be standing on them) |
| `.` | Wait one turn |
| `?` | Help |
| `q` | Save and quit |

Reach depth 10, defeat the Dragon, and claim the dungeon's treasure to win.

## Development

```bash
pip install -e ".[dev]" 2>/dev/null || pip install pytest
pytest
```

The codebase is split into small, focused modules:

- `dungeon.py` — room/corridor generation and connectivity
- `fov.py` — line-of-sight visibility
- `entities.py` — the player and monsters
- `items.py` — items and inventory
- `game.py` — the turn loop tying everything together
- `render.py` — ASCII rendering of the game state
- `save.py` — JSON save/load
- `__main__.py` — the interactive CLI
