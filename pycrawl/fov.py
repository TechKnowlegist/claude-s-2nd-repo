"""Field-of-view computation using Bresenham line-of-sight checks."""

from __future__ import annotations

from .constants import TRANSPARENT_TILES
from .dungeon import Dungeon


def _bresenham_line(x0: int, y0: int, x1: int, y1: int) -> list[tuple[int, int]]:
    points = []
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    x, y = x0, y0
    while True:
        points.append((x, y))
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy
    return points


def _has_line_of_sight(dungeon: Dungeon, x0: int, y0: int, x1: int, y1: int) -> bool:
    line = _bresenham_line(x0, y0, x1, y1)
    # Every tile strictly between the endpoints must be transparent.
    for x, y in line[1:-1]:
        if dungeon.tile_at(x, y) not in TRANSPARENT_TILES:
            return False
    return True


def compute_visible(dungeon: Dungeon, origin: tuple[int, int], radius: int) -> set[tuple[int, int]]:
    """Returns the set of tiles visible from `origin` within `radius`,
    accounting for walls blocking line of sight."""
    ox, oy = origin
    visible: set[tuple[int, int]] = {origin}

    for y in range(oy - radius, oy + radius + 1):
        for x in range(ox - radius, ox + radius + 1):
            if not dungeon.in_bounds(x, y):
                continue
            if (x - ox) ** 2 + (y - oy) ** 2 > radius * radius:
                continue
            if _has_line_of_sight(dungeon, ox, oy, x, y):
                visible.add((x, y))

    return visible
