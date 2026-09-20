"""Save/load a Game to and from a JSON file on disk."""

from __future__ import annotations

import json
from pathlib import Path

from .game import Game

DEFAULT_SAVE_PATH = Path.home() / ".pycrawl" / "save.json"


def save_game(game: Game, path: Path = DEFAULT_SAVE_PATH) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(game.to_dict()))


def load_game(path: Path = DEFAULT_SAVE_PATH) -> Game:
    data = json.loads(path.read_text())
    return Game.from_dict(data)


def save_exists(path: Path = DEFAULT_SAVE_PATH) -> bool:
    return path.exists()


def delete_save(path: Path = DEFAULT_SAVE_PATH) -> None:
    if path.exists():
        path.unlink()
