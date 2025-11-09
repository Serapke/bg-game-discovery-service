require "test_helper"

class GameTypeTest < ActiveSupport::TestCase
  test "should not save game type without name" do
    game_type = GameType.new
    assert_not game_type.save, "Saved game type without a name"
  end

  test "should save game type with valid name" do
    game_type = GameType.new(name: "cooperative")
    assert game_type.save, "Failed to save valid game type"
  end

  test "should not save duplicate game type name" do
    GameType.create!(name: "adventure")
    duplicate = GameType.new(name: "adventure")
    assert_not duplicate.save, "Saved game type with duplicate name"
  end

  test "should associate with board games" do
    game_type = GameType.create!(name: "euro")
    game_category = GameCategory.create!(name: "strategy")
    board_game = BoardGame.create!(
      name: "Test Game",
      min_players: 2,
      max_players: 4,
      game_types: [game_type],
      game_categories: [game_category]
    )

    assert_includes game_type.board_games, board_game
    assert_includes board_game.game_types, game_type
  end
end
