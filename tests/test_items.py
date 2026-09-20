import random

from pycrawl.items import Inventory, Item, random_item


def test_inventory_add_respects_capacity():
    inv = Inventory(capacity=2)
    assert inv.add(Item("A", "!", "d", "potion"))
    assert inv.add(Item("B", "!", "d", "potion"))
    assert not inv.add(Item("C", "!", "d", "potion"))
    assert len(inv.items) == 2


def test_inventory_remove_at():
    inv = Inventory()
    inv.add(Item("A", "!", "d", "potion"))
    removed = inv.remove_at(0)
    assert removed.name == "A"
    assert inv.items == []


def test_inventory_remove_out_of_range_returns_none():
    inv = Inventory()
    assert inv.remove_at(5) is None


def test_random_item_scales_with_depth():
    rng = random.Random(0)
    shallow = [random_item(rng, 1) for _ in range(50)]
    rng2 = random.Random(0)
    deep = [random_item(rng2, 10) for _ in range(50)]
    shallow_weapons = [i.value for i in shallow if i.kind == "weapon"]
    deep_weapons = [i.value for i in deep if i.kind == "weapon"]
    if shallow_weapons and deep_weapons:
        assert max(deep_weapons) >= max(shallow_weapons)


def test_item_serialization_round_trip():
    item = Item("Potion", "!", "heals", "potion", value=10)
    restored = Item.from_dict(item.to_dict())
    assert restored == item


def test_inventory_serialization_round_trip():
    inv = Inventory()
    inv.add(Item("A", "!", "d", "potion", value=5))
    restored = Inventory.from_dict(inv.to_dict())
    assert restored.items[0].name == "A"
    assert restored.capacity == inv.capacity
