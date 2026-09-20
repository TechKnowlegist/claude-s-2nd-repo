import random

from pycrawl.constants import STAIRS_DOWN, WALKABLE_TILES
from pycrawl.dungeon import generate_dungeon


def test_generates_at_least_one_room():
    dungeon = generate_dungeon(60, 22, random.Random(1))
    assert len(dungeon.rooms) >= 1


def test_stairs_are_reachable_from_start():
    dungeon = generate_dungeon(60, 22, random.Random(42))
    start = dungeon.rooms[0].center
    reachable = dungeon.flood_fill_reachable(start)
    assert dungeon.stairs_down in reachable


def test_stairs_tile_is_stairs_symbol():
    dungeon = generate_dungeon(60, 22, random.Random(7))
    x, y = dungeon.stairs_down
    assert dungeon.tile_at(x, y) == STAIRS_DOWN


def test_same_seed_produces_same_dungeon():
    d1 = generate_dungeon(60, 22, random.Random(99))
    d2 = generate_dungeon(60, 22, random.Random(99))
    assert d1.grid == d2.grid
    assert d1.stairs_down == d2.stairs_down


def test_different_seeds_usually_differ():
    d1 = generate_dungeon(60, 22, random.Random(1))
    d2 = generate_dungeon(60, 22, random.Random(2))
    assert d1.grid != d2.grid


def test_all_rooms_are_walkable_interior():
    dungeon = generate_dungeon(60, 22, random.Random(5))
    for room in dungeon.rooms:
        cx, cy = room.center
        assert dungeon.tile_at(cx, cy) in WALKABLE_TILES


def test_dungeon_is_bordered_by_walls():
    dungeon = generate_dungeon(40, 20, random.Random(3))
    for x in range(dungeon.width):
        assert dungeon.tile_at(x, 0) == "#"
        assert dungeon.tile_at(x, dungeon.height - 1) == "#"
    for y in range(dungeon.height):
        assert dungeon.tile_at(0, y) == "#"
        assert dungeon.tile_at(dungeon.width - 1, y) == "#"
