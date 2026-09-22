# Rift Blade

A top-down action game built in Godot 4. You start with nothing but a
basic sword. Step through portals in the Nexus hub into different
**dimensions** — each with its own art style — fight waves of enemies and
a boss, and bring shards home to upgrade your sword at the Forge.

## Dimensions

Every dimension is drawn entirely in code, in its own visual style:

| Dimension | Style | Boss |
|---|---|---|
| The Pixel Realm | chunky pixel-art sprites | King Blob |
| The ASCII Void | glowing text glyphs | The Glyph Daemon |
| The Geometric Rift | clean geometric shapes | The Perfect Form |

Clearing a dimension unlocks the next one and drops shards. An **Online
Arena** portal is already placed in the Nexus as a hook for a future PvP
mode.

## Playing

Open `riftblade/` as a project in the [Godot 4.4+ editor](https://godotengine.org/)
and press Play (F5), or run headless from the command line:

```bash
godot --path riftblade
```

Controls: WASD/arrows or a stick to move, Space/left click/controller X to
swing your sword, Shift/right click/controller A to dash, `1`-`3` (or
shoulder buttons) to use carried items, `E`/Y to interact with the Forge,
Esc to pause.

## What there is to fight for

- **Loot**: shards (currency), Rift Chests, and rarity-tiered items
  (potions, speed boosts, supercharges, rift shields) that drop from
  enemies and chests.
- **The Forge**: spend shards in the Nexus to permanently upgrade your
  sword's damage, swing speed, reach, crit chance, and your max health.
- **Enemies**: chasers, brutes and shooters, each dimension tougher than
  the last, culminating in a unique boss fight.

## Development

The gameplay code lives in `scripts/`:

- `game_state.gd` — autoload: shards, sword upgrades, save/load, input map
- `dimensions.gd` / `items.gd` — static data for worlds and loot
- `art.gd` — all procedural rendering (pixel/ASCII/geometric styles)
- `world.gd` — arena layout, wave spawning, the Nexus hub
- `player.gd` / `enemy.gd` / `projectile.gd` / `pickup.gd` / `portal.gd` / `forge.gd`
- `hud.gd` — HUD, Forge menu, pause menu
- `main.gd` — swaps between the Nexus and dimensions

An end-to-end test that drives an entire play session (hub → Forge →
portal → waves → combat → items → boss → death → save/load) lives in
`tests/smoke_test.gd`. Run it headless:

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
real audio, more content per dimension, a Steamworks integration
(achievements, cloud saves) via a plugin like GodotSteam, and the online
PvP mode the Nexus already has a portal for.
