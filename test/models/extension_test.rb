require "test_helper"

class ExtensionTest < ActiveSupport::TestCase
  def setup
    @board_game = board_games(:catan)
    @extension = Extension.new(
      name: "Test Extension",
      board_game: @board_game,
      min_players: 3,
      max_players: 5,
      min_playing_time: 45,
      max_playing_time: 75,
      rating: 8.0
    )
  end

  test "should be valid with valid attributes" do
    assert @extension.valid?
  end

  test "should require name" do
    @extension.name = nil
    assert_not @extension.valid?
    assert_includes @extension.errors[:name], "can't be blank"
  end

  test "should require board_game" do
    @extension.board_game = nil
    assert_not @extension.valid?
    assert_includes @extension.errors[:board_game], "must exist"
  end

  test "min_players can be nil" do
    @extension.min_players = nil
    assert @extension.valid?
  end

  test "max_players can be nil" do
    @extension.max_players = nil
    assert @extension.valid?
  end

  test "min_players should be greater than 0 when present" do
    @extension.min_players = 0
    assert_not @extension.valid?
    assert_includes @extension.errors[:min_players], "must be greater than 0"
  end

  test "max_players should be greater than or equal to min_players when both present" do
    @extension.min_players = 5
    @extension.max_players = 3
    assert_not @extension.valid?
    assert_includes @extension.errors[:max_players], "must be greater than or equal to 5"
  end

  test "rating should be between 0 and 10 when present" do
    @extension.rating = -1
    assert_not @extension.valid?
    assert_includes @extension.errors[:rating], "must be greater than or equal to 0"

    @extension.rating = 11
    assert_not @extension.valid?
    assert_includes @extension.errors[:rating], "must be less than or equal to 10"
  end

  test "rating can be nil" do
    @extension.rating = nil
    assert @extension.valid?
  end

  test "min_playing_time should be greater than 0 when present" do
    @extension.min_playing_time = 0
    assert_not @extension.valid?
    assert_includes @extension.errors[:min_playing_time], "must be greater than 0"
  end

  test "max_playing_time should be greater than or equal to min_playing_time when both present" do
    @extension.min_playing_time = 60
    @extension.max_playing_time = 30
    assert_not @extension.valid?
    assert_includes @extension.errors[:max_playing_time], "must be greater than or equal to 60"
  end

  test "playing times can be nil" do
    @extension.min_playing_time = nil
    @extension.max_playing_time = nil
    assert @extension.valid?
  end

  test "should belong to board_game" do
    extension = extensions(:catan_seafarers)
    assert_equal board_games(:catan), extension.board_game
  end

  test "should be valid with only name and board_game" do
    minimal_extension = Extension.new(
      name: "Minimal Extension",
      board_game: @board_game
    )
    assert minimal_extension.valid?
  end
end