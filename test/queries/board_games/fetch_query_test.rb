require "test_helper"

module BoardGames
  # noinspection RubyArgCount
  class FetchQueryTest < ActiveSupport::TestCase
    setup do
      @query = BoardGames::FetchQuery.new
      @catan = board_games(:catan)
      @wingspan = board_games(:wingspan)
    end

    test "call without ids returns all board games" do
      result = @query.call(ids: nil)

      assert_equal BoardGame.count, result.count
      assert_includes result, @catan
      assert_includes result, @wingspan
    end

    test "call with ids returns only specified board games" do
      ids = [@catan.id, @wingspan.id]
      result = @query.call(ids: ids)

      assert_equal 2, result.count
      assert_includes result, @catan
      assert_includes result, @wingspan
    end

    test "call with single id returns only that board game" do
      result = @query.call(ids: [@catan.id])

      assert_equal 1, result.count
      assert_includes result, @catan
      refute_includes result, @wingspan
    end

    test "call with empty ids array raises ArgumentError" do
      assert_raises(ArgumentError, "No valid IDs provided") do
        @query.call(ids: [])
      end
    end

    test "can initialize with custom relation" do
      custom_relation = BoardGame.where(name: @catan.name)
      query = BoardGames::FetchQuery.new(custom_relation)

      result = query.call(ids: nil)

      assert_equal 1, result.count
      assert_includes result, @catan
    end

    test "call with player_count filter returns games matching player count" do
      result = @query.call(ids: nil, player_count: 4)

      # Should include games where 4 players is within min/max range
      result.each do |game|
        assert game.min_players <= 4
        assert game.max_players >= 4
      end
    end

    test "call with max_playing_time filter returns games under time limit" do
      result = @query.call(ids: nil, max_playing_time: 60)

      result.each do |game|
        assert game.max_playing_time <= 60 if game.max_playing_time.present?
      end
    end

    test "call with game_types filter returns games with specified types" do
      strategy_type = game_types(:strategy)
      result = @query.call(ids: nil, game_types: [strategy_type.name])

      result.each do |game|
        assert_includes game.game_types.map(&:name), strategy_type.name
      end
    end

    test "call with min_rating filter returns games above rating threshold" do
      result = @query.call(ids: nil, min_rating: 7.0)

      result.each do |game|
        assert game.rating >= 7.0 if game.rating.present?
      end
    end

    test "call with multiple filters applies all filters" do
      strategy_type = game_types(:strategy)
      result = @query.call(
        ids: nil,
        player_count: 4,
        max_playing_time: 120,
        game_types: [strategy_type.name],
        min_rating: 7.0
      )

      result.each do |game|
        assert game.min_players <= 4
        assert game.max_players >= 4
        assert game.max_playing_time <= 120 if game.max_playing_time.present?
        assert_includes game.game_types.map(&:name), strategy_type.name
        assert game.rating >= 7.0 if game.rating.present?
      end
    end

    test "call with ids and filters returns filtered subset" do
      ids = [@catan.id, @wingspan.id]
      result = @query.call(ids: ids, player_count: 4)

      # Should only return games from the ID list that match filters
      result.each do |game|
        assert_includes ids, game.id
        assert game.min_players <= 4
        assert game.max_players >= 4
      end
    end
  end
end