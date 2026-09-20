from pycrawl.dungeon import Dungeon
from pycrawl.fov import compute_visible


def make_open_room(width=15, height=15):
    dungeon = Dungeon(width, height)
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            dungeon.set_tile(x, y, ".")
    return dungeon


def test_origin_is_always_visible():
    dungeon = make_open_room()
    visible = compute_visible(dungeon, (7, 7), radius=5)
    assert (7, 7) in visible


def test_open_room_visible_within_radius():
    dungeon = make_open_room()
    visible = compute_visible(dungeon, (7, 7), radius=4)
    assert (7, 3) in visible  # straight line, 4 tiles up
    assert (11, 7) in visible  # straight line, 4 tiles right


def test_beyond_radius_is_not_visible():
    dungeon = make_open_room()
    visible = compute_visible(dungeon, (7, 7), radius=3)
    assert (7, 13) not in visible


def test_wall_blocks_line_of_sight():
    dungeon = make_open_room()
    # Build a wall segment directly between origin and a target tile.
    for y in range(1, 14):
        dungeon.set_tile(7, y, "#")

    visible = compute_visible(dungeon, (2, 8), radius=10)
    assert (12, 8) not in visible


def test_visibility_is_symmetric_in_open_space():
    dungeon = make_open_room()
    from_a = compute_visible(dungeon, (3, 3), radius=6)
    assert (7, 6) in from_a
