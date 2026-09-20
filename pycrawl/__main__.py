"""Command-line entry point for PyCrawl."""

from __future__ import annotations

import argparse
import sys

from .game import Game
from .render import render_game
from .save import delete_save, load_game, save_exists, save_game

BANNER = r"""
 ____        ____                    _
|  _ \ _   _/ ___|_ __ __ ___      _| |
| |_) | | | | |   | '__/ _` \ \ /\ / / |
|  __/| |_| | |___| | | (_| |\ V  V /| |
|_|    \__, |\____|_|  \__,_| \_/\_/ |_|
       |___/
"""


def run_interactive(game: Game, use_color: bool) -> None:
    while not game.game_over and not game.quit:
        print("\033c" if use_color else "\n" * 2, end="")
        print(render_game(game, use_color=use_color))
        try:
            cmd = input("\n> ")
        except (EOFError, KeyboardInterrupt):
            print("\nSaving and exiting...")
            save_game(game)
            return
        game.process_command(cmd)
        if game.quit:
            game.quit = False  # a save should resume mid-game, not stay "quit"
            save_game(game)
            print("Game saved. See you next time.")
        elif game.game_over:
            print(render_game(game, use_color=use_color))
            if game.won:
                print("\n*** VICTORY! ***")
            else:
                print("\n*** GAME OVER ***")
            delete_save()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="pycrawl", description="A procedural roguelike dungeon crawler.")
    parser.add_argument("--seed", type=int, default=None, help="Dungeon seed for reproducible runs.")
    parser.add_argument("--no-color", action="store_true", help="Disable ANSI colors.")
    parser.add_argument("--continue", dest="cont", action="store_true", help="Continue your saved game.")
    parser.add_argument("--new", action="store_true", help="Force a new game, discarding any save.")
    args = parser.parse_args(argv)

    use_color = not args.no_color and sys.stdout.isatty()

    print(BANNER)
    if args.cont and save_exists() and not args.new:
        game = load_game()
        print("Loaded your saved game.")
    else:
        if args.new:
            delete_save()
        game = Game(seed=args.seed)
        print(f"New game started (seed={game.seed}). Type '?' for help.")

    run_interactive(game, use_color)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
