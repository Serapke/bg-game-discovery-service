require "test_helper"

class BggBoardGameAssociationTest < ActiveSupport::TestCase
  def setup
    @game_type = GameType.create!(name: "test_type")
    @game_category = GameCategory.create!(name: "test_category")
    @board_game = BoardGame.create!(
      name: "Test Game",
      year_published: 2020,
      min_players: 2,
      max_players: 4,
      game_types: [@game_type],
      game_categories: [@game_category]
    )
    @bgg_association = BggBoardGameAssociation.new(
      board_game: @board_game,
      bgg_id: 12345
    )
  end

  test "should be valid with valid attributes" do
    assert @bgg_association.valid?
  end

  test "should require board_game" do
    @bgg_association.board_game = nil
    assert_not @bgg_association.valid?
    assert_includes @bgg_association.errors[:board_game], "must exist"
  end

  test "should require bgg_id" do
    @bgg_association.bgg_id = nil
    assert_not @bgg_association.valid?
    assert_includes @bgg_association.errors[:bgg_id], "can't be blank"
  end

  test "bgg_id should be a positive integer" do
    @bgg_association.bgg_id = 0
    assert_not @bgg_association.valid?
    assert_includes @bgg_association.errors[:bgg_id], "must be greater than 0"

    @bgg_association.bgg_id = -1
    assert_not @bgg_association.valid?
    assert_includes @bgg_association.errors[:bgg_id], "must be greater than 0"
  end

  test "bgg_id should be unique" do
    @bgg_association.save!

    duplicate = BggBoardGameAssociation.new(
      board_game: @board_game,
      bgg_id: 12345
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:bgg_id], "has already been taken"
  end

  test "should allow same board_game with different bgg_id" do
    @bgg_association.save!

    another_association = BggBoardGameAssociation.new(
      board_game: @board_game,
      bgg_id: 67890
    )

    assert another_association.valid?
  end

  test "should belong to board_game" do
    @bgg_association.save!

    assert_equal @board_game, @bgg_association.board_game
    assert_equal @bgg_association, @board_game.bgg_board_game_association
  end

  test "should be destroyed when board_game is destroyed" do
    @bgg_association.save!

    assert_difference 'BggBoardGameAssociation.count', -1 do
      @board_game.destroy
    end
  end
end