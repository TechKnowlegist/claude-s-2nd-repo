from pycrawl.game import Game


def make_game(seed=123):
    return Game(seed=seed)


def test_new_game_starts_at_depth_one_and_alive():
    game = make_game()
    assert game.depth == 1
    assert game.player.alive
    assert not game.game_over


def test_unknown_command_reports_error_without_crashing():
    game = make_game()
    messages = game.process_command("gibberish")
    assert any("Unknown command" in m for m in messages)
    assert not game.game_over


def test_inventory_and_help_do_not_move_monsters():
    game = make_game()
    monster_positions_before = [(m.x, m.y) for m in game.monsters]
    game.process_command("i")
    game.process_command("?")
    monster_positions_after = [(m.x, m.y) for m in game.monsters]
    assert monster_positions_before == monster_positions_after


def test_moving_into_wall_does_not_move_player():
    game = make_game()
    # The tile just outside the dungeon border is always a wall.
    game.player.x, game.player.y = 1, 1
    game.dungeon.grid[0][1] = "#"
    before = (game.player.x, game.player.y)
    game.process_command("n")
    assert (game.player.x, game.player.y) == before


def test_descend_requires_standing_on_stairs():
    game = make_game()
    messages = game.process_command(">")
    assert any("no stairs" in m for m in messages)
    assert game.depth == 1


def test_descend_on_stairs_advances_depth():
    game = make_game()
    game.player.x, game.player.y = game.dungeon.stairs_down
    game.process_command(">")
    assert game.depth == 2


def test_quit_sets_quit_flag_not_game_over():
    game = make_game()
    game.process_command("q")
    assert game.quit
    assert not game.game_over


def test_processing_command_after_quit_is_a_no_op():
    game = make_game()
    game.process_command("q")
    messages = game.process_command("n")
    assert "already left" in messages[0].lower()


def test_processing_command_after_game_over_is_a_no_op():
    game = make_game()
    game.game_over = True
    messages = game.process_command("n")
    assert "over" in messages[0].lower()


def test_pick_up_gold_adds_to_purse_not_inventory():
    game = make_game()
    from pycrawl.items import Item

    pos = (game.player.x, game.player.y)
    game.items_on_ground[pos] = Item("Gold", "$", "10 gold", "gold", value=10)
    game.process_command("g")
    assert game.player.gold == 10
    assert pos not in game.items_on_ground
    assert len(game.player.inventory.items) == 0


def test_full_playthrough_smoke_test_many_moves():
    game = make_game(seed=7)
    commands = ["n", "s", "e", "w", "ne", "nw", "se", "sw", ".", "i", "?"] * 10
    for cmd in commands:
        if game.game_over:
            break
        game.process_command(cmd)
    # Should never crash, and player should still be in a valid state.
    assert game.player.hp >= 0


def test_save_and_load_round_trip_preserves_state():
    from pycrawl.game import Game

    game = make_game(seed=55)
    game.process_command("n")
    game.player.gold = 42
    data = game.to_dict()
    restored = Game.from_dict(data)

    assert restored.seed == game.seed
    assert restored.depth == game.depth
    assert restored.player.x == game.player.x
    assert restored.player.y == game.player.y
    assert restored.player.gold == 42
    assert restored.dungeon.grid == game.dungeon.grid
    assert restored.dungeon.stairs_down == game.dungeon.stairs_down
