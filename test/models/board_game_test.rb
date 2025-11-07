require "test_helper"

class BoardGameTest < ActiveSupport::TestCase
  def setup
    @game_type = GameType.create!(name: "test_type")
    @board_game = BoardGame.new(
      name: "Test Game",
      min_players: 2,
      max_players: 4,
      min_playing_time: 30,
      max_playing_time: 60,
      rating: 7.5,
      game_types: [@game_type]
    )
  end

  test "should be valid with valid attributes" do
    assert @board_game.valid?
  end

  test "should require at least one game type" do
    @board_game.game_types = []
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:game_types], "must have at least one game type"
  end

  test "should allow multiple game types" do
    strategy = game_types(:strategy)
    family = game_types(:family)
    @board_game.save!
    @board_game.game_types = [strategy, family]

    assert @board_game.valid?
    assert_equal 2, @board_game.game_types.count
  end

  test "should associate with game types" do
    @board_game.save!

    assert_includes @board_game.game_types, @game_type
    assert_includes @game_type.board_games, @board_game
  end

  test "should require name" do
    @board_game.name = nil
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:name], "can't be blank"
  end

  test "should require min_players" do
    @board_game.min_players = nil
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:min_players], "can't be blank"
  end

  test "should require max_players" do
    @board_game.max_players = nil
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:max_players], "can't be blank"
  end

  test "min_players should be greater than 0" do
    @board_game.min_players = 0
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:min_players], "must be greater than 0"
  end

  test "max_players should be greater than or equal to min_players" do
    @board_game.min_players = 4
    @board_game.max_players = 2
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:max_players], "must be greater than or equal to 4"
  end

  test "rating should be between 0 and 10" do
    @board_game.rating = -1
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:rating], "must be greater than or equal to 0"

    @board_game.rating = 11
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:rating], "must be less than or equal to 10"
  end

  test "rating can be nil" do
    @board_game.rating = nil
    assert @board_game.valid?
  end

  test "min_playing_time should be greater than 0 when present" do
    @board_game.min_playing_time = 0
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:min_playing_time], "must be greater than 0"
  end

  test "max_playing_time should be greater than or equal to min_playing_time when both present" do
    @board_game.min_playing_time = 60
    @board_game.max_playing_time = 30
    assert_not @board_game.valid?
    assert_includes @board_game.errors[:max_playing_time], "must be greater than or equal to 60"
  end

  test "playing times can be nil" do
    @board_game.min_playing_time = nil
    @board_game.max_playing_time = nil
    assert @board_game.valid?
  end

  test "should have many extensions" do
    board_game = board_games(:catan)
    extension = Extension.create!(
      name: "Test Extension",
      board_game: board_game,
      min_players: 3,
      max_players: 5
    )

    assert_includes board_game.extensions, extension
  end

  test "should destroy associated extensions when destroyed" do
    board_game = board_games(:catan)
    extension = Extension.create!(
      name: "Test Extension",
      board_game: board_game,
      min_players: 3,
      max_players: 5
    )

    # Catan has 2 fixture extensions + 1 created above = 3 total
    assert_difference 'Extension.count', -3 do
      board_game.destroy
    end
  end

  test "search_by_name scope should find games by name substring" do
    catan = board_games(:catan)
    ticket = board_games(:ticket_to_ride)

    results = BoardGame.search_by_name("cat")
    assert_includes results, catan
    assert_not_includes results, ticket
  end

  test "search_by_name scope should be case insensitive" do
    catan = board_games(:catan)

    results = BoardGame.search_by_name("CATAN")
    assert_includes results, catan
  end

  test "search_by_name scope should return all games when name is blank" do
    all_games = BoardGame.all
    results = BoardGame.search_by_name("")

    assert_equal all_games.count, results.count
  end

  test "for_player_count scope should find games that support player count" do
    catan = board_games(:catan)  # 3-4 players
    wingspan = board_games(:wingspan)  # 1-5 players

    results = BoardGame.for_player_count(3)
    assert_includes results, catan
    assert_includes results, wingspan

    results = BoardGame.for_player_count(1)
    assert_not_includes results, catan
    assert_includes results, wingspan
  end

  test "for_player_count scope should return all games when player_count is blank" do
    all_games = BoardGame.all
    results = BoardGame.for_player_count("")

    assert_equal all_games.count, results.count
  end

  test "for_playing_time scope should find games that support playing time" do
    catan = board_games(:catan)  # 60-90 minutes
    azul = board_games(:azul)    # 30-45 minutes

    results = BoardGame.for_playing_time(70)
    assert_includes results, catan
    assert_not_includes results, azul

    results = BoardGame.for_playing_time(40)
    assert_not_includes results, catan
    assert_includes results, azul
  end

  test "max_playing_time_under scope should find games with max time under limit" do
    azul = board_games(:azul)        # 30-45 minutes
    ticket = board_games(:ticket_to_ride)  # 30-60 minutes

    results = BoardGame.max_playing_time_under(50)
    assert_includes results, azul
    assert_not_includes results, ticket
  end

  test "min_playing_time_over scope should find games with min time over limit" do
    catan = board_games(:catan)      # 60-90 minutes
    wingspan = board_games(:wingspan)  # 40-70 minutes

    results = BoardGame.min_playing_time_over(50)
    assert_includes results, catan
    assert_not_includes results, wingspan
  end

  test "playing time scopes should return all games when time is blank" do
    all_games = BoardGame.all

    assert_equal all_games.count, BoardGame.for_playing_time("").count
    assert_equal all_games.count, BoardGame.max_playing_time_under("").count
    assert_equal all_games.count, BoardGame.min_playing_time_over("").count
  end
end