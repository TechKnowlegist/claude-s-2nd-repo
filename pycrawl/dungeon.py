"""Procedural dungeon generation: rooms connected by corridors."""

from __future__ import annotations

from dataclasses import dataclass
from random import Random

from .constants import FLOOR, STAIRS_DOWN, WALL


@dataclass
class Room:
    x: int
    y: int
    w: int
    h: int

    @property
    def center(self) -> tuple[int, int]:
        return (self.x + self.w // 2, self.y + self.h // 2)

    @property
    def x2(self) -> int:
        return self.x + self.w - 1

    @property
    def y2(self) -> int:
        return self.y + self.h - 1

    def intersects(self, other: "Room", padding: int = 1) -> bool:
        return (
            self.x - padding <= other.x2
            and self.x2 + padding >= other.x
            and self.y - padding <= other.y2
            and self.y2 + padding >= other.y
        )


class Dungeon:
    """A grid-based dungeon level made of rectangular rooms and L-shaped
    corridors. Tiles are addressed as grid[y][x]."""

    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.grid = [[WALL for _ in range(width)] for _ in range(height)]
        self.rooms: list[Room] = []
        self.stairs_down: tuple[int, int] | None = None

    def in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.width and 0 <= y < self.height

    def tile_at(self, x: int, y: int) -> str:
        if not self.in_bounds(x, y):
            return WALL
        return self.grid[y][x]

    def set_tile(self, x: int, y: int, tile: str) -> None:
        if self.in_bounds(x, y):
            self.grid[y][x] = tile

    def _carve_room(self, room: Room) -> None:
        for y in range(room.y, room.y + room.h):
            for x in range(room.x, room.x + room.w):
                self.set_tile(x, y, FLOOR)

    def _carve_h_corridor(self, x1: int, x2: int, y: int) -> None:
        for x in range(min(x1, x2), max(x1, x2) + 1):
            self.set_tile(x, y, FLOOR)

    def _carve_v_corridor(self, y1: int, y2: int, x: int) -> None:
        for y in range(min(y1, y2), max(y1, y2) + 1):
            self.set_tile(x, y, FLOOR)

    def flood_fill_reachable(self, start: tuple[int, int]) -> set[tuple[int, int]]:
        """Returns every floor-like tile reachable from `start`."""
        from .constants import WALKABLE_TILES

        seen = {start}
        frontier = [start]
        while frontier:
            cx, cy = frontier.pop()
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nx, ny = cx + dx, cy + dy
                if (nx, ny) in seen:
                    continue
                if self.tile_at(nx, ny) in WALKABLE_TILES:
                    seen.add((nx, ny))
                    frontier.append((nx, ny))
        return seen


def generate_dungeon(
    width: int,
    height: int,
    rng: Random,
    max_rooms: int = 12,
    room_min: int = 4,
    room_max: int = 9,
) -> Dungeon:
    """Generates a connected dungeon. Guarantees every room is reachable
    from the first room, and places a single down staircase in the room
    farthest (by corridor path) from the start.
    """
    dungeon = Dungeon(width, height)
    attempts = max_rooms * 6

    for _ in range(attempts):
        if len(dungeon.rooms) >= max_rooms:
            break
        w = rng.randint(room_min, room_max)
        h = rng.randint(room_min, room_max)
        x = rng.randint(1, width - w - 2)
        y = rng.randint(1, height - h - 2)
        new_room = Room(x, y, w, h)

        if any(new_room.intersects(r) for r in dungeon.rooms):
            continue

        dungeon._carve_room(new_room)

        if dungeon.rooms:
            prev_x, prev_y = dungeon.rooms[-1].center
            new_x, new_y = new_room.center
            if rng.random() < 0.5:
                dungeon._carve_h_corridor(prev_x, new_x, prev_y)
                dungeon._carve_v_corridor(prev_y, new_y, new_x)
            else:
                dungeon._carve_v_corridor(prev_y, new_y, prev_x)
                dungeon._carve_h_corridor(prev_x, new_x, new_y)

        dungeon.rooms.append(new_room)

    if not dungeon.rooms:
        # Degenerate fallback: carve one big room so the game never breaks.
        fallback = Room(1, 1, width - 2, height - 2)
        dungeon._carve_room(fallback)
        dungeon.rooms.append(fallback)

    start = dungeon.rooms[0].center
    reachable_rooms = [r for r in dungeon.rooms if r.center in dungeon.flood_fill_reachable(start)]
    farthest_room = max(
        reachable_rooms,
        key=lambda r: (r.center[0] - start[0]) ** 2 + (r.center[1] - start[1]) ** 2,
    )
    stairs_x, stairs_y = farthest_room.center
    dungeon.set_tile(stairs_x, stairs_y, STAIRS_DOWN)
    dungeon.stairs_down = (stairs_x, stairs_y)

    return dungeon
