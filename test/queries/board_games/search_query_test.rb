require "test_helper"

module BoardGames
  class SearchQueryTest < ActiveSupport::TestCase
    setup do
      @query = BoardGames::SearchQuery.new
    end

    test "call without params returns all board games" do
      result = @query.call({})

      assert_equal BoardGame.count, result.count
    end

    test "call with name filters by name" do
      result = @query.call({ name: "catan" })

      assert result.count > 0
      assert result.all? { |game| game.name.downcase.include?("catan") }
    end

    test "call with player_count filters by player count" do
      result = @query.call({ player_count: 3 })

      result.each do |game|
        assert game.min_players <= 3
        assert game.max_players >= 3
      end
    end

    test "call with playing_time filters by playing time" do
      result = @query.call({ playing_time: 60 })

      result.each do |game|
        assert game.min_playing_time <= 60
        assert game.max_playing_time >= 60
      end
    end

    test "call with max_playing_time filters games under max time" do
      result = @query.call({ max_playing_time: 50 })

      result.each do |game|
        assert game.max_playing_time <= 50
      end
    end

    test "call with min_playing_time filters games over min time" do
      result = @query.call({ min_playing_time: 50 })

      result.each do |game|
        assert game.min_playing_time >= 50
      end
    end

    test "call with multiple filters applies all filters" do
      result = @query.call({
        name: "wing",
        player_count: 2,
        min_playing_time: 30,
        max_playing_time: 60
      })

      result.each do |game|
        assert game.name.downcase.include?("wing")
        assert game.min_players <= 2
        assert game.max_players >= 2
        assert game.min_playing_time >= 30
        assert game.max_playing_time <= 60
      end
    end

    test "call raises error for blank name parameter" do
      assert_raises(ArgumentError, "Name parameter cannot be empty") do
        @query.call({ name: "" })
      end
    end

    test "call ignores blank player_count parameter" do
      result_all = @query.call({})
      result_blank = @query.call({ player_count: "" })

      assert_equal result_all.count, result_blank.count
    end

    test "includes associations in results" do
      result = @query.call({})

      # Verify associations are eager loaded
      assert_not ActiveRecord::Associations::Preloader.new(
        records: [result.first],
        associations: [:extensions, :game_types, :game_categories]
      ).empty?
    end

    test "can initialize with custom relation" do
      catan = board_games(:catan)
      custom_relation = BoardGame.where(name: catan.name)
      query = BoardGames::SearchQuery.new(custom_relation)

      result = query.call({})

      assert_equal 1, result.count
      assert_includes result, catan
    end
  end
end