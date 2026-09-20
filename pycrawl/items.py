"""Item definitions and the inventory that holds them."""

from __future__ import annotations

from dataclasses import dataclass, field
from random import Random


@dataclass
class Item:
    name: str
    symbol: str
    description: str
    kind: str  # "potion", "scroll", "weapon", "armor", "gold"
    value: int = 0  # heal amount / attack bonus / defense bonus / gold amount

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "symbol": self.symbol,
            "description": self.description,
            "kind": self.kind,
            "value": self.value,
        }

    @staticmethod
    def from_dict(data: dict) -> "Item":
        return Item(
            name=data["name"],
            symbol=data["symbol"],
            description=data["description"],
            kind=data["kind"],
            value=data.get("value", 0),
        )


def make_potion(rng: Random, depth: int) -> Item:
    heal = rng.randint(8, 14) + depth
    return Item("Potion of Healing", "!", f"Restores {heal} HP.", "potion", heal)


def make_scroll(rng: Random, depth: int) -> Item:
    return Item(
        "Scroll of Blinking",
        "?",
        "Teleports you to a random explored-adjacent safe tile.",
        "scroll",
        0,
    )


def make_weapon(rng: Random, depth: int) -> Item:
    names = ["Dagger", "Short Sword", "Long Sword", "War Axe", "Great Sword"]
    tier = min(len(names) - 1, depth // 2)
    bonus = 2 + tier * 2 + rng.randint(0, 2)
    return Item(names[tier], "/", f"A weapon granting +{bonus} attack.", "weapon", bonus)


def make_armor(rng: Random, depth: int) -> Item:
    names = ["Padded Vest", "Leather Armor", "Chainmail", "Plate Mail", "Dragon Scale"]
    tier = min(len(names) - 1, depth // 2)
    bonus = 1 + tier * 2 + rng.randint(0, 2)
    return Item(names[tier], "[", f"Armor granting +{bonus} defense.", "armor", bonus)


def make_gold(rng: Random, depth: int) -> Item:
    amount = rng.randint(5, 15) * (depth + 1)
    return Item("Gold", "$", f"{amount} gold pieces.", "gold", amount)


ITEM_FACTORIES = [make_potion, make_scroll, make_weapon, make_armor, make_gold]
ITEM_WEIGHTS = [35, 15, 15, 15, 20]


def random_item(rng: Random, depth: int) -> Item:
    factory = rng.choices(ITEM_FACTORIES, weights=ITEM_WEIGHTS, k=1)[0]
    return factory(rng, depth)


@dataclass
class Inventory:
    items: list[Item] = field(default_factory=list)
    capacity: int = 12

    def add(self, item: Item) -> bool:
        if len(self.items) >= self.capacity:
            return False
        self.items.append(item)
        return True

    def remove_at(self, index: int) -> Item | None:
        if 0 <= index < len(self.items):
            return self.items.pop(index)
        return None

    def to_dict(self) -> dict:
        return {"items": [i.to_dict() for i in self.items], "capacity": self.capacity}

    @staticmethod
    def from_dict(data: dict) -> "Inventory":
        return Inventory(
            items=[Item.from_dict(i) for i in data.get("items", [])],
            capacity=data.get("capacity", 12),
        )
