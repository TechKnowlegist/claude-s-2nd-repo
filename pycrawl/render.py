"""ASCII rendering of the game state to a terminal-friendly string."""

from __future__ import annotations

from .constants import Color, UNKNOWN

MAX_LOG_LINES = 6


def render_game(game, use_color: bool = True) -> str:
    lines = []
    lines.append(_render_map(game, use_color))
    lines.append("")
    lines.append(_render_status(game))
    lines.append(_render_log(game))
    return "\n".join(lines)


def _c(code: str, text: str, use_color: bool) -> str:
    if not use_color:
        return text
    return f"{code}{text}{Color.RESET}"


def _render_map(game, use_color: bool) -> str:
    dungeon = game.dungeon
    rows = []
    monster_positions = {(m.x, m.y): m for m in game.monsters if m.alive}
    item_positions = {(it_x, it_y): item for (it_x, it_y), item in game.items_on_ground.items()}

    for y in range(dungeon.height):
        row_chars = []
        for x in range(dungeon.width):
            pos = (x, y)
            if pos == (game.player.x, game.player.y):
                row_chars.append(_c(Color.BOLD + Color.CYAN, "@", use_color))
                continue

            if pos in game.visible:
                if pos in monster_positions:
                    row_chars.append(_c(Color.RED, monster_positions[pos].symbol, use_color))
                elif pos in item_positions:
                    row_chars.append(_c(Color.YELLOW, item_positions[pos].symbol, use_color))
                else:
                    tile = dungeon.tile_at(x, y)
                    row_chars.append(_render_tile(tile, use_color, dim=False))
            elif pos in game.seen:
                tile = dungeon.tile_at(x, y)
                row_chars.append(_render_tile(tile, use_color, dim=True))
            else:
                row_chars.append(UNKNOWN)
        rows.append("".join(row_chars))
    return "\n".join(rows)


def _render_tile(tile: str, use_color: bool, dim: bool) -> str:
    if tile == "#":
        return _c(Color.GRAY, tile, use_color)
    if tile == ">":
        return _c(Color.MAGENTA, tile, use_color)
    color = Color.DIM if dim else ""
    return _c(color, tile, use_color) if color else tile


def _render_status(game) -> str:
    p = game.player
    weapon = p.weapon.name if p.weapon else "fists"
    armor = p.armor.name if p.armor else "no armor"
    return (
        f"Depth {game.depth}  HP {p.hp}/{p.max_hp}  Lv {p.level} (XP {p.xp}/{p.xp_to_next})  "
        f"ATK {p.attack} DEF {p.defense}  Gold {p.gold}\n"
        f"Wielding: {weapon}  Wearing: {armor}"
    )


def _render_log(game) -> str:
    tail = game.log[-MAX_LOG_LINES:]
    return "\n".join(tail)
