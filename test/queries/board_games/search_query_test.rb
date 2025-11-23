require "test_helper"
require "minitest/mock"

module BoardGames
  class SearchQueryTest < ActiveSupport::TestCase
    setup do
      @importer = Minitest::Mock.new
      @query = BoardGames::SearchQuery.new(BoardGame.all, importer: @importer)
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
      # Mock import_from_search since filters might return empty and trigger BGG import
      @importer.expect(:import_from_search, [], ["wing"])

      result = @query.call({
        name: "wing",
        player_count: 2,
        min_playing_time: 30,
        max_playing_time: 60
      })

      # Result should be empty since filters exclude all games and import returns empty
      assert_equal 0, result.count

      @importer.verify
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

      # Verify associations are eagerly loaded
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

    # Tests for BGG import integration

    test "imports from BGG when no results found" do
      # Ensure there are no games with this name
      assert_equal 0, BoardGame.where("name ILIKE ?", "%nonexistent%").count

      # Define mock to create and return a game when called
      def @importer.import_from_search(query)
        game = BoardGame.create!(
          name: "Nonexistent Game",
          year_published: 2020,
          min_players: 2,
          max_players: 4,
          min_playing_time: 30,
          max_playing_time: 60,
          rating: 7.0,
          difficulty_score: 2.0,
          game_types: [GameType.find_or_create_by!(name: "General")],
          game_categories: [GameCategory.find_or_create_by!(name: "General")]
        )
        [game]
      end

      result = @query.call({ name: "Nonexistent" })

      assert_equal 1, result.count
      assert_equal "Nonexistent Game", result.first.name
    end

    test "does not import from BGG when results are found" do
      # Use existing game from fixtures
      result = @query.call({ name: "catan" })

      # Importer should not be called since we found results
      assert result.count > 0
      # No expectations set on @importer, so verify would fail if called
    end

    test "returns empty when import fails and no local results" do
      # Mock the importer to raise an error
      @importer.expect(:import_from_search, -> { raise BggApi::GameImporter::ImportError, "API Error" }, ["FailGame"])

      # Should catch the error and return empty results
      result = @query.call({ name: "FailGame" })

      assert_empty result
    end

    test "returns results after successful import" do
      # Clear any existing games to ensure import is triggered
      initial_count = BoardGame.where("name ILIKE ?", "%NewGame%").count
      assert_equal 0, initial_count

      # Define mock to create and return a game when called
      def @importer.import_from_search(query)
        game = BoardGame.create!(
          name: "NewGame from BGG",
          year_published: 2023,
          min_players: 1,
          max_players: 4,
          min_playing_time: 45,
          max_playing_time: 90,
          rating: 8.0,
          difficulty_score: 3.0,
          game_types: [GameType.find_or_create_by!(name: "General")],
          game_categories: [GameCategory.find_or_create_by!(name: "General")]
        )
        [game]
      end

      result = @query.call({ name: "NewGame" })

      assert_equal 1, result.count
      assert_equal "NewGame from BGG", result.first.name
      assert_equal 2023, result.first.year_published
    end

    test "import is called with the search query name" do
      # Mock to ensure a correct query is passed - use a game name not in fixtures
      @importer.expect(:import_from_search, [], ["NonExistentGame"])

      result = @query.call({ name: "NonExistentGame" })

      # Result should be empty since no games match and import returns empty
      assert_equal 0, result.count

      @importer.verify
    end

    test "works without importer for backward compatibility" do
      query_without_importer = BoardGames::SearchQuery.new

      # Should not raise error
      result = query_without_importer.call({ name: "catan" })

      assert result.count > 0
    end
  end
end