from pycrawl.game import Game
from pycrawl.save import delete_save, load_game, save_exists, save_game


def test_save_creates_file_and_load_restores_game(tmp_path):
    path = tmp_path / "save.json"
    game = Game(seed=321)
    game.player.gold = 99

    assert not save_exists(path)
    save_game(game, path)
    assert save_exists(path)

    restored = load_game(path)
    assert restored.player.gold == 99
    assert restored.seed == game.seed
    assert restored.depth == game.depth


def test_delete_save_removes_file(tmp_path):
    path = tmp_path / "save.json"
    game = Game(seed=1)
    save_game(game, path)
    assert save_exists(path)
    delete_save(path)
    assert not save_exists(path)


def test_delete_save_on_missing_file_is_a_no_op(tmp_path):
    path = tmp_path / "does_not_exist.json"
    delete_save(path)  # should not raise
    assert not save_exists(path)
