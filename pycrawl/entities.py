"""Player and monster entities."""

from __future__ import annotations

from dataclasses import dataclass, field
from random import Random

from .items import Inventory, Item


@dataclass
class Player:
    x: int
    y: int
    hp: int = 30
    max_hp: int = 30
    base_attack: int = 4
    base_defense: int = 2
    level: int = 1
    xp: int = 0
    xp_to_next: int = 20
    gold: int = 0
    inventory: Inventory = field(default_factory=Inventory)
    weapon: Item | None = None
    armor: Item | None = None

    @property
    def attack(self) -> int:
        return self.base_attack + (self.weapon.value if self.weapon else 0)

    @property
    def defense(self) -> int:
        return self.base_defense + (self.armor.value if self.armor else 0)

    @property
    def alive(self) -> bool:
        return self.hp > 0

    def take_damage(self, amount: int) -> None:
        self.hp = max(0, self.hp - amount)

    def heal(self, amount: int) -> int:
        before = self.hp
        self.hp = min(self.max_hp, self.hp + amount)
        return self.hp - before

    def gain_xp(self, amount: int) -> list[str]:
        messages = [f"You gain {amount} XP."]
        self.xp += amount
        while self.xp >= self.xp_to_next:
            self.xp -= self.xp_to_next
            self.level += 1
            self.max_hp += 8
            self.hp = self.max_hp
            self.base_attack += 2
            self.base_defense += 1
            self.xp_to_next = int(self.xp_to_next * 1.5)
            messages.append(
                f"You feel stronger! Welcome to level {self.level} "
                f"(HP {self.max_hp}, ATK {self.base_attack}, DEF {self.base_defense})."
            )
        return messages

    def to_dict(self) -> dict:
        return {
            "x": self.x, "y": self.y, "hp": self.hp, "max_hp": self.max_hp,
            "base_attack": self.base_attack, "base_defense": self.base_defense,
            "level": self.level, "xp": self.xp, "xp_to_next": self.xp_to_next,
            "gold": self.gold, "inventory": self.inventory.to_dict(),
            "weapon": self.weapon.to_dict() if self.weapon else None,
            "armor": self.armor.to_dict() if self.armor else None,
        }

    @staticmethod
    def from_dict(data: dict) -> "Player":
        return Player(
            x=data["x"], y=data["y"], hp=data["hp"], max_hp=data["max_hp"],
            base_attack=data["base_attack"], base_defense=data["base_defense"],
            level=data["level"], xp=data["xp"], xp_to_next=data["xp_to_next"],
            gold=data["gold"], inventory=Inventory.from_dict(data["inventory"]),
            weapon=Item.from_dict(data["weapon"]) if data.get("weapon") else None,
            armor=Item.from_dict(data["armor"]) if data.get("armor") else None,
        )


MONSTER_TEMPLATES = [
    # (name, symbol, min_depth, hp, attack, defense, xp_reward)
    ("Rat", "r", 1, 6, 2, 0, 3),
    ("Giant Spider", "s", 1, 9, 3, 1, 5),
    ("Goblin", "g", 1, 12, 4, 1, 8),
    ("Skeleton", "k", 3, 16, 5, 2, 12),
    ("Orc", "o", 4, 22, 7, 2, 18),
    ("Zombie", "z", 5, 26, 5, 4, 20),
    ("Troll", "T", 7, 38, 9, 4, 32),
    ("Wraith", "W", 9, 30, 11, 3, 40),
    ("Dragon", "D", 12, 60, 14, 6, 100),
]


@dataclass
class Monster:
    name: str
    symbol: str
    x: int
    y: int
    hp: int
    max_hp: int
    attack: int
    defense: int
    xp_reward: int
    aggro: bool = False

    @property
    def alive(self) -> bool:
        return self.hp > 0

    def take_damage(self, amount: int) -> None:
        self.hp = max(0, self.hp - amount)

    def to_dict(self) -> dict:
        return {
            "name": self.name, "symbol": self.symbol, "x": self.x, "y": self.y,
            "hp": self.hp, "max_hp": self.max_hp, "attack": self.attack,
            "defense": self.defense, "xp_reward": self.xp_reward, "aggro": self.aggro,
        }

    @staticmethod
    def from_dict(data: dict) -> "Monster":
        return Monster(**data)


def spawn_monster(rng: Random, depth: int, x: int, y: int) -> Monster:
    candidates = [t for t in MONSTER_TEMPLATES if t[2] <= depth]
    if not candidates:
        candidates = [MONSTER_TEMPLATES[0]]
    # Weight towards tougher monsters as depth increases, but keep variety.
    weights = [1 + max(0, depth - t[2]) for t in candidates]
    name, symbol, _min_depth, hp, attack, defense, xp = rng.choices(
        candidates, weights=weights, k=1
    )[0]
    scale = 1 + (depth - 1) * 0.12
    hp = max(1, int(hp * scale))
    attack = max(1, int(attack * scale))
    return Monster(name, symbol, x, y, hp, hp, attack, defense, xp)
