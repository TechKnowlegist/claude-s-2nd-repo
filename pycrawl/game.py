"""The main game loop: ties dungeon, entities, items, and FOV together."""

from __future__ import annotations

import random

from .constants import (
    DIRECTIONS,
    FOV_RADIUS,
    MAP_HEIGHT,
    MAP_WIDTH,
    MAX_INVENTORY,
    WALKABLE_TILES,
)
from .dungeon import Dungeon, generate_dungeon
from .entities import Monster, Player, spawn_monster
from .fov import compute_visible
from .items import Item, random_item

MAX_DEPTH = 10  # the dragon on this level is the final boss


class Game:
    def __init__(self, seed: int | None = None, width: int = MAP_WIDTH, height: int = MAP_HEIGHT):
        self.seed = seed if seed is not None else random.randrange(2**31)
        self.rng = random.Random(self.seed)
        self.width = width
        self.height = height

        self.depth = 0
        self.dungeon: Dungeon = None  # type: ignore[assignment]
        self.monsters: list[Monster] = []
        self.items_on_ground: dict[tuple[int, int], Item] = {}
        self.visible: set[tuple[int, int]] = set()
        self.seen: set[tuple[int, int]] = set()
        self.log: list[str] = []
        self.game_over = False
        self.won = False
        self.quit = False

        self.player = Player(x=0, y=0)
        self._enter_new_level()
        self._message("You descend into the dungeon. Find the stairs (>) and go deeper.")

    # -- level management -------------------------------------------------

    def _enter_new_level(self) -> None:
        self.depth += 1
        max_rooms = min(18, 8 + self.depth)
        self.dungeon = generate_dungeon(self.width, self.height, self.rng, max_rooms=max_rooms)

        start_room = self.dungeon.rooms[0]
        self.player.x, self.player.y = start_room.center

        self.monsters = []
        self.items_on_ground = {}

        occupied = {(self.player.x, self.player.y), self.dungeon.stairs_down}
        num_monsters = min(14, 3 + self.depth)
        for _ in range(num_monsters):
            pos = self._random_floor_tile(occupied)
            if pos is None:
                break
            occupied.add(pos)
            self.monsters.append(spawn_monster(self.rng, self.depth, pos[0], pos[1]))

        num_items = self.rng.randint(3, 6)
        for _ in range(num_items):
            pos = self._random_floor_tile(occupied)
            if pos is None:
                break
            occupied.add(pos)
            self.items_on_ground[pos] = random_item(self.rng, self.depth)

        if self.depth == MAX_DEPTH:
            boss_pos = self.dungeon.stairs_down
            self.monsters.append(Monster("Dragon", "D", boss_pos[0], boss_pos[1], 80, 80, 16, 6, 200))

        self.seen = set()
        self._recompute_visibility()

    def _random_floor_tile(self, occupied: set[tuple[int, int]]) -> tuple[int, int] | None:
        for _ in range(200):
            room = self.rng.choice(self.dungeon.rooms)
            x = self.rng.randint(room.x, room.x2)
            y = self.rng.randint(room.y, room.y2)
            if (x, y) not in occupied and self.dungeon.tile_at(x, y) in WALKABLE_TILES:
                return (x, y)
        return None

    def _recompute_visibility(self) -> None:
        self.visible = compute_visible(self.dungeon, (self.player.x, self.player.y), FOV_RADIUS)
        self.seen |= self.visible

    # -- messaging ----------------------------------------------------------

    def _message(self, text: str) -> None:
        self.log.append(text)

    # -- commands -------------------------------------------------------------

    def process_command(self, raw: str) -> list[str]:
        """Executes one player command and returns the new messages produced.
        A "turn" (monster moves) is only consumed by actions that take game
        time: moving, waiting, attacking, using/equipping items, and picking
        things up. Looking at inventory or asking for help does not."""
        if self.game_over:
            return ["The game is over. Start a new game to keep playing."]
        if self.quit:
            return ["You have already left the dungeon."]

        cmd = raw.strip().lower()
        start_index = len(self.log)
        took_turn = False

        if cmd in ("q", "quit", "exit"):
            self.quit = True
            self._message("You leave the dungeon. Farewell, adventurer.")
        elif cmd in DIRECTIONS:
            took_turn = self._move_player(*DIRECTIONS[cmd])
        elif cmd in (".", "wait", "z"):
            self._message("You wait.")
            took_turn = True
        elif cmd in (">", "descend"):
            took_turn = self._descend()
        elif cmd in ("g", "get", "pickup"):
            took_turn = self._pick_up()
        elif cmd in ("i", "inventory", "inv"):
            self._show_inventory()
        elif cmd.startswith("u ") or cmd.startswith("use "):
            took_turn = self._use_item(cmd.split(maxsplit=1)[1])
        elif cmd.startswith("e ") or cmd.startswith("equip "):
            took_turn = self._equip_item(cmd.split(maxsplit=1)[1])
        elif cmd.startswith("d ") or cmd.startswith("drop "):
            took_turn = self._drop_item(cmd.split(maxsplit=1)[1])
        elif cmd in ("?", "help"):
            self._show_help()
        else:
            self._message(f"Unknown command: '{raw}'. Type '?' for help.")

        if took_turn and not self.game_over:
            self._run_monster_turns()
            self._recompute_visibility()
            self._check_game_over()

        return self.log[start_index:]

    def _move_player(self, dx: int, dy: int) -> bool:
        nx, ny = self.player.x + dx, self.player.y + dy
        blocker = next((m for m in self.monsters if m.alive and m.x == nx and m.y == ny), None)
        if blocker is not None:
            self._player_attack(blocker)
            return True

        if self.dungeon.tile_at(nx, ny) not in WALKABLE_TILES:
            self._message("You bump into a wall.")
            return False

        self.player.x, self.player.y = nx, ny
        if (nx, ny) in self.items_on_ground:
            item = self.items_on_ground[(nx, ny)]
            self._message(f"You see {item.name} here. ('g' to pick it up)")
        return True

    def _player_attack(self, monster: Monster) -> None:
        damage = max(1, self.player.attack - monster.defense + self.rng.randint(-1, 2))
        monster.take_damage(damage)
        self._message(f"You hit the {monster.name} for {damage} damage.")
        monster.aggro = True
        if not monster.alive:
            self._message(f"You defeat the {monster.name}!")
            self.monsters = [m for m in self.monsters if m is not monster]
            for msg in self.player.gain_xp(monster.xp_reward):
                self._message(msg)
            if self.rng.random() < 0.3:
                loot = random_item(self.rng, self.depth)
                if loot.kind == "gold":
                    self.player.gold += loot.value
                    self._message(f"The {monster.name} dropped {loot.value} gold.")
                elif self.player.inventory.add(loot):
                    self._message(f"The {monster.name} dropped {loot.name}, added to your pack.")

    def _descend(self) -> bool:
        if (self.player.x, self.player.y) != self.dungeon.stairs_down:
            self._message("There are no stairs here.")
            return False
        if self.depth >= MAX_DEPTH:
            self._message("You have already reached the deepest level.")
            return False
        self._enter_new_level()
        self._message(f"You descend to depth {self.depth}.")
        return True

    def _pick_up(self) -> bool:
        pos = (self.player.x, self.player.y)
        item = self.items_on_ground.get(pos)
        if item is None:
            self._message("There is nothing here to pick up.")
            return False
        if item.kind == "gold":
            self.player.gold += item.value
            self._message(f"You pick up {item.value} gold.")
            del self.items_on_ground[pos]
            return True
        if len(self.player.inventory.items) >= MAX_INVENTORY:
            self._message("Your inventory is full.")
            return False
        self.player.inventory.add(item)
        del self.items_on_ground[pos]
        self._message(f"You pick up {item.name}.")
        return True

    def _resolve_item_index(self, arg: str) -> int | None:
        try:
            index = int(arg) - 1
        except ValueError:
            matches = [
                i for i, it in enumerate(self.player.inventory.items)
                if it.name.lower().startswith(arg.strip().lower())
            ]
            if len(matches) == 1:
                return matches[0]
            return None
        return index

    def _use_item(self, arg: str) -> bool:
        index = self._resolve_item_index(arg)
        if index is None or not (0 <= index < len(self.player.inventory.items)):
            self._message("You don't have that item.")
            return False
        item = self.player.inventory.items[index]
        if item.kind == "potion":
            healed = self.player.heal(item.value)
            self._message(f"You drink the {item.name} and recover {healed} HP.")
            self.player.inventory.remove_at(index)
            return True
        if item.kind == "scroll":
            self._blink()
            self.player.inventory.remove_at(index)
            return True
        if item.kind in ("weapon", "armor"):
            self._equip_item(arg)
            return True
        self._message(f"You can't use the {item.name} directly.")
        return False

    def _blink(self) -> None:
        candidates = [
            pos for pos in self.seen
            if self.dungeon.tile_at(*pos) in WALKABLE_TILES
            and not any(m.alive and (m.x, m.y) == pos for m in self.monsters)
        ]
        if not candidates:
            self._message("The scroll fizzles; nowhere safe to blink to.")
            return
        self.player.x, self.player.y = self.rng.choice(candidates)
        self._message("You blink to a new location in a flash of light.")

    def _equip_item(self, arg: str) -> bool:
        index = self._resolve_item_index(arg)
        if index is None or not (0 <= index < len(self.player.inventory.items)):
            self._message("You don't have that item.")
            return False
        item = self.player.inventory.items[index]
        if item.kind == "weapon":
            old = self.player.weapon
            self.player.weapon = item
            self.player.inventory.remove_at(index)
            if old:
                self.player.inventory.add(old)
            self._message(f"You wield the {item.name}.")
            return True
        if item.kind == "armor":
            old = self.player.armor
            self.player.armor = item
            self.player.inventory.remove_at(index)
            if old:
                self.player.inventory.add(old)
            self._message(f"You wear the {item.name}.")
            return True
        self._message(f"You can't equip the {item.name}.")
        return False

    def _drop_item(self, arg: str) -> bool:
        index = self._resolve_item_index(arg)
        if index is None or not (0 <= index < len(self.player.inventory.items)):
            self._message("You don't have that item.")
            return False
        pos = (self.player.x, self.player.y)
        if pos in self.items_on_ground:
            self._message("There's already something here.")
            return False
        item = self.player.inventory.remove_at(index)
        self.items_on_ground[pos] = item
        self._message(f"You drop the {item.name}.")
        return True

    def _show_inventory(self) -> None:
        if not self.player.inventory.items:
            self._message("Your inventory is empty.")
            return
        lines = ["Inventory:"]
        for i, item in enumerate(self.player.inventory.items, start=1):
            lines.append(f"  {i}. {item.name} ({item.symbol}) - {item.description}")
        self._message("\n".join(lines))

    def _show_help(self) -> None:
        self._message(
            "Movement: n/s/e/w/ne/nw/se/sw (or hjkl+yubn). "
            "'g' pick up, 'i' inventory, 'u <#>' use item, 'e <#>' equip item, "
            "'d <#>' drop item, '>' descend stairs, '.' wait, 'q' quit."
        )

    # -- monster AI -----------------------------------------------------------

    def _run_monster_turns(self) -> None:
        for monster in list(self.monsters):
            if not monster.alive:
                continue
            self._monster_turn(monster)

    def _monster_turn(self, monster: Monster) -> None:
        px, py = self.player.x, self.player.y
        mx, my = monster.x, monster.y
        distance_sq = (px - mx) ** 2 + (py - my) ** 2

        if (mx, my) in self.visible and distance_sq <= FOV_RADIUS * FOV_RADIUS:
            monster.aggro = True

        if not monster.aggro:
            if self.rng.random() < 0.3:
                self._wander(monster)
            return

        if abs(px - mx) <= 1 and abs(py - my) <= 1 and (px, py) != (mx, my):
            self._monster_attack(monster)
            return

        step_x = (px > mx) - (px < mx)
        step_y = (py > my) - (py < my)
        for dx, dy in ((step_x, step_y), (step_x, 0), (0, step_y)):
            if dx == 0 and dy == 0:
                continue
            nx, ny = mx + dx, my + dy
            if self.dungeon.tile_at(nx, ny) in WALKABLE_TILES and not self._occupied(nx, ny):
                monster.x, monster.y = nx, ny
                break

    def _wander(self, monster: Monster) -> None:
        dx, dy = self.rng.choice([(0, 1), (0, -1), (1, 0), (-1, 0)])
        nx, ny = monster.x + dx, monster.y + dy
        if self.dungeon.tile_at(nx, ny) in WALKABLE_TILES and not self._occupied(nx, ny):
            monster.x, monster.y = nx, ny

    def _occupied(self, x: int, y: int) -> bool:
        if (x, y) == (self.player.x, self.player.y):
            return True
        return any(m.alive and m.x == x and m.y == y for m in self.monsters)

    def _monster_attack(self, monster: Monster) -> None:
        damage = max(1, monster.attack - self.player.defense + self.rng.randint(-1, 2))
        self.player.take_damage(damage)
        self._message(f"The {monster.name} hits you for {damage} damage.")

    def _check_game_over(self) -> None:
        if not self.player.alive:
            self.game_over = True
            self._message("You have died. Game over.")
        elif self.depth >= MAX_DEPTH and not any(m.name == "Dragon" and m.alive for m in self.monsters):
            self.game_over = True
            self.won = True
            self._message("You slay the Dragon and claim the dungeon's treasure. You win!")

    # -- serialization --------------------------------------------------------

    def to_dict(self) -> dict:
        return {
            "seed": self.seed,
            "rng_state": self.rng.getstate(),
            "width": self.width,
            "height": self.height,
            "depth": self.depth,
            "dungeon": {
                "grid": self.dungeon.grid,
                "width": self.dungeon.width,
                "height": self.dungeon.height,
                "stairs_down": self.dungeon.stairs_down,
                "rooms": [[r.x, r.y, r.w, r.h] for r in self.dungeon.rooms],
            },
            "player": self.player.to_dict(),
            "monsters": [m.to_dict() for m in self.monsters],
            "items_on_ground": [
                {"x": x, "y": y, "item": item.to_dict()}
                for (x, y), item in self.items_on_ground.items()
            ],
            "visible": list(self.visible),
            "seen": list(self.seen),
            "log": self.log,
            "game_over": self.game_over,
            "won": self.won,
            "quit": self.quit,
        }

    @staticmethod
    def from_dict(data: dict) -> "Game":
        game = Game.__new__(Game)
        game.seed = data["seed"]
        game.rng = random.Random()
        rng_state = data["rng_state"]
        game.rng.setstate((rng_state[0], tuple(rng_state[1]), rng_state[2]))
        game.width = data["width"]
        game.height = data["height"]
        game.depth = data["depth"]

        from .dungeon import Room

        d = data["dungeon"]
        dungeon = Dungeon(d["width"], d["height"])
        dungeon.grid = d["grid"]
        dungeon.stairs_down = tuple(d["stairs_down"]) if d["stairs_down"] else None
        dungeon.rooms = [Room(*r) for r in d["rooms"]]
        game.dungeon = dungeon

        game.player = Player.from_dict(data["player"])
        game.monsters = [Monster.from_dict(m) for m in data["monsters"]]
        game.items_on_ground = {
            (entry["x"], entry["y"]): Item.from_dict(entry["item"])
            for entry in data["items_on_ground"]
        }
        game.visible = {tuple(p) for p in data["visible"]}
        game.seen = {tuple(p) for p in data["seen"]}
        game.log = data["log"]
        game.game_over = data["game_over"]
        game.won = data["won"]
        game.quit = data.get("quit", False)
        return game
