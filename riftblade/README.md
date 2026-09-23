# Rift Blade

A top-down action game built in Godot 4. You start with nothing but a
basic sword and float around the Nexus hub, a weightless space between
worlds. Step through a portal into a **dimension** — each with its own
art style — and crawl room by room through waves of enemies that get
harder the deeper you go, ending in a boss fight. Loot swords and armor,
equip them from your inventory, and spend shards at the Nexus Forge to
permanently upgrade your gear. Every sound and piece of music is
synthesized in code, same as the art — no external asset files at all.

## Dimensions

Every dimension is drawn entirely in code, in its own visual style, and
is built as a line of enclosed rooms connected by gated doorways: each
room holds one wave, and its door only opens once the room is cleared.

| Dimension | Style | Rooms | Boss |
|---|---|---|---|
| The Pixel Realm | chunky pixel-art sprites | 4 + boss room | King Blob |
| The ASCII Void | glowing text glyphs | 5 + boss room | The Glyph Daemon |
| The Geometric Rift | clean geometric shapes | 6 + boss room | The Perfect Form |

Clearing a dimension's boss unlocks the next one and drops a guaranteed
piece of gear plus shards. An **Online Arena** portal is already placed
in the Nexus as a hook for a future PvP mode.

## Playing

Open `riftblade/` as a project in the [Godot 4.4+ editor](https://godotengine.org/)
and press Play (F5), or run headless from the command line:

```bash
godot --path riftblade
```

Controls: WASD/arrows or a stick to move, Space/left click/controller X to
swing your sword, Shift/right click/controller A to dash, `1`-`3` (or
shoulder buttons) to use carried items, `E`/Y to interact with the Forge,
`I`/Select to open your inventory, Esc to pause.

## What there is to fight for

- **Consumables**: potions, speed boosts, supercharges and rift shields —
  carried in 3 quick-use slots, consumed on use.
- **Gear**: swords and armor drop from enemies and Rift Chests (a boss
  always drops one) and go straight into your permanent inventory (`I`).
  Equip whichever raises your damage/reach (swords) or max health and
  damage reduction (armor) the most — better gear shows up as an
  outlined blade or a colored ring around your character.
- **The Forge**: spend shards in the Nexus to permanently upgrade your
  base sword's damage, swing speed, reach, crit chance, and max health,
  stacking on top of whatever sword/armor you have equipped.
- **Enemies**: chasers, brutes and shooters, each dimension's rooms
  tougher than the last, culminating in a unique boss fight.

## Audio

There isn't a single audio file in the project — `scripts/audio.gd`
synthesizes every sound effect and music loop as raw waveforms at
runtime (sine/square/saw oscillators with an envelope), the same way
`art.gd` draws everything in code instead of using sprites. Each
dimension (plus the Nexus) has its own looping chiptune-style track, and
sword swings, hits, pickups, gates opening, portals, and the boss roar
all have their own procedural one-shot sound.

## Development

The gameplay code lives in `scripts/`:

- `game_state.gd` — autoload: shards, sword upgrades, gear inventory, save/load, input map
- `audio.gd` — autoload: procedurally-synthesized sound effects and music
- `dimensions.gd` / `items.gd` — static data for worlds and loot (consumables + gear)
- `art.gd` — all procedural rendering (pixel/ASCII/geometric styles)
- `world.gd` — room-by-room dungeon layout, gated doors, wave spawning, the Nexus hub
- `player.gd` / `enemy.gd` / `projectile.gd` / `pickup.gd` / `portal.gd` / `forge.gd`
- `hud.gd` — HUD, Forge menu, Inventory menu, pause menu
- `main.gd` — swaps between the Nexus and dimensions

An end-to-end test that drives an entire play session (hub → Forge →
portal → rooms/gates → combat → items → gear/inventory → boss → death →
save/load) lives in `tests/smoke_test.gd`. Run it headless:

```bash
godot --headless --fixed-fps 60 --path riftblade res://tests/smoke_test.tscn
```

`tests/screenshots.gd` renders a screenshot of the Nexus and each
dimension (needs a display, e.g. via `xvfb-run`):

```bash
xvfb-run godot --path riftblade res://tests/screenshots.tscn -- /tmp/shots
```

## Roadmap toward Steam

This is a solid vertical slice, not a store-ready build yet. Still ahead:
more content per dimension, hiding the later dimensions behind a real
secret rather than a simple "clear the last one" gate, a Steamworks
integration (achievements, cloud saves) via a plugin like GodotSteam,
and the online PvP mode the Nexus already has a portal for.
