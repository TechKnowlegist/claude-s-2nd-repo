"""Shared constants: tile symbols, colors, and direction mappings."""

WALL = "#"
FLOOR = "."
STAIRS_DOWN = ">"
DOOR = "+"
UNKNOWN = " "

TRANSPARENT_TILES = {FLOOR, STAIRS_DOWN, DOOR}
WALKABLE_TILES = {FLOOR, STAIRS_DOWN, DOOR}

# Colors are only used when the terminal supports them; render.py degrades
# gracefully to plain text otherwise.
class Color:
    RESET = "\033[0m"
    DIM = "\033[2m"
    BOLD = "\033[1m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"
    WHITE = "\033[37m"
    GRAY = "\033[90m"


DIRECTIONS = {
    "n": (0, -1), "north": (0, -1), "k": (0, -1),
    "s": (0, 1), "south": (0, 1), "j": (0, 1),
    "e": (1, 0), "east": (1, 0), "l": (1, 0),
    "w": (-1, 0), "west": (-1, 0), "h": (-1, 0),
    "ne": (1, -1), "northeast": (1, -1), "u": (1, -1),
    "nw": (-1, -1), "northwest": (-1, -1), "y": (-1, -1),
    "se": (1, 1), "southeast": (1, 1), "m": (1, 1),
    "sw": (-1, 1), "southwest": (-1, 1), "b": (-1, 1),
}

FOV_RADIUS = 8
MAP_WIDTH = 60
MAP_HEIGHT = 22
MAX_INVENTORY = 12
