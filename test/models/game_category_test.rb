require "test_helper"

class GameCategoryTest < ActiveSupport::TestCase
  test "should not save game category without name" do
    game_category = GameCategory.new
    assert_not game_category.save, "Saved game category without a name"
  end

  test "should save game category with valid name" do
    game_category = GameCategory.new(name: "Cooperative")
    assert game_category.save, "Failed to save valid game category"
  end

  test "should not save duplicate game category name" do
    GameCategory.create!(name: "Adventure")
    duplicate = GameCategory.new(name: "Adventure")
    assert_not duplicate.save, "Saved game category with duplicate name"
  end

  test "should associate with board games" do
    game_category = GameCategory.create!(name: "Euro")
    game_type = game_types(:strategy)
    board_game = BoardGame.create!(
      name: "Test Game",
      min_players: 2,
      max_players: 4,
      game_types: [game_type],
      game_categories: [game_category]
    )

    assert_includes game_category.board_games, board_game
    assert_includes board_game.game_categories, game_category
  end
end
