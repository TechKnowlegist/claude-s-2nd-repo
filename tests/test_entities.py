from pycrawl.entities import Monster, Player
from pycrawl.items import Item


def test_player_takes_damage():
    p = Player(x=0, y=0, hp=20, max_hp=20)
    p.take_damage(5)
    assert p.hp == 15
    assert p.alive


def test_player_damage_cannot_go_below_zero():
    p = Player(x=0, y=0, hp=5, max_hp=20)
    p.take_damage(999)
    assert p.hp == 0
    assert not p.alive


def test_player_heal_caps_at_max_hp():
    p = Player(x=0, y=0, hp=18, max_hp=20)
    healed = p.heal(10)
    assert p.hp == 20
    assert healed == 2


def test_gain_xp_levels_up_and_carries_remainder():
    p = Player(x=0, y=0, xp=0, xp_to_next=20, level=1)
    messages = p.gain_xp(25)
    assert p.level == 2
    assert p.xp == 5
    assert any("level 2" in m for m in messages)


def test_weapon_and_armor_bonuses_apply():
    p = Player(x=0, y=0, base_attack=4, base_defense=2)
    p.weapon = Item("Sword", "/", "desc", "weapon", value=3)
    p.armor = Item("Mail", "[", "desc", "armor", value=2)
    assert p.attack == 7
    assert p.defense == 4


def test_monster_death():
    m = Monster("Rat", "r", 0, 0, hp=5, max_hp=5, attack=1, defense=0, xp_reward=3)
    m.take_damage(5)
    assert not m.alive


def test_player_serialization_round_trip():
    p = Player(x=1, y=2, hp=10, max_hp=20, gold=15)
    p.weapon = Item("Sword", "/", "desc", "weapon", value=3)
    restored = Player.from_dict(p.to_dict())
    assert restored.x == 1 and restored.y == 2
    assert restored.gold == 15
    assert restored.weapon.name == "Sword"
