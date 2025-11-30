# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"
require "minitest/mock"

module BggApi
  class GameImporterTest < ActiveSupport::TestCase
    setup do
      @client = Minitest::Mock.new
      @importer = BggApi::GameImporter.new(client: @client)
    end

    # Tests for import_from_search

    test "import_from_search imports board games from search results" do
      search_results = {
        total: 2,
        items: [
          { id: "13", type: "boardgame", name: "Catan", year_published: "1995" },
          { id: "2807", type: "boardgame", name: "Pandemic", year_published: "2008" }
        ]
      }

      game_details = [
        {
          id: 13,
          thing_type: "boardgame",
          name: "Catan",
          year_published: 1995,
          min_players: 3,
          max_players: 4,
          min_playing_time: 60,
          max_playing_time: 120,
          playing_time: 120,
          rating: 7.12,
          complexity: 2.35,
          user_ratings_count: 50000,
          categories: %w[Economic Negotiation],
          mechanics: ["Dice Rolling", "Trading"]
        },
        {
          id: 2807,
          thing_type: "boardgame",
          name: "Pandemic",
          year_published: 2008,
          min_players: 2,
          max_players: 4,
          min_playing_time: 45,
          max_playing_time: 45,
          playing_time: 45,
          rating: 7.60,
          complexity: 2.40,
          user_ratings_count: 75000,
          categories: ["Medical"],
          mechanics: ["Cooperative Play"]
        }
      ]

      @client.expect(:search, search_results, ["Catan"])
      @client.expect(:get_details, game_details, [[13, 2807], { min_user_ratings: 1000 }])

      imported = @importer.import_from_search("Catan")

      assert_equal 2, imported.length
      assert_equal "Catan", imported[0].name
      assert_equal "Pandemic", imported[1].name
      assert imported[0].persisted?
      assert imported[1].persisted?

      @client.verify
    end

    test "import_from_search with custom min_user_ratings" do
      search_results = {
        total: 1,
        items: [{ id: "13", type: "boardgame", name: "Catan", year_published: "1995" }]
      }

      game_details = [{
        id: 13,
        thing_type: "boardgame",
        name: "Catan",
        year_published: 1995,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        playing_time: 120,
        rating: 7.12,
        complexity: 2.35,
        user_ratings_count: 50000,
        categories: [],
        mechanics: []
      }]

      @client.expect(:search, search_results, ["Catan"])
      @client.expect(:get_details, game_details, [[13], { min_user_ratings: 5000 }])

      imported = @importer.import_from_search("Catan", min_user_ratings: 5000)

      assert_equal 1, imported.length
      @client.verify
    end

    test "import_from_search returns empty array when no search results" do
      search_results = { total: 0, items: [] }

      @client.expect(:search, search_results, ["NonexistentGame"])

      imported = @importer.import_from_search("NonexistentGame")

      assert_empty imported
      @client.verify
    end

    test "import_from_search returns empty array when all games filtered by min ratings" do
      search_results = {
        total: 1,
        items: [{ id: "99999", type: "boardgame", name: "Unpopular Game", year_published: "2020" }]
      }

      @client.expect(:search, search_results, ["Unpopular"])
      @client.expect(:get_details, [], [[99999], { min_user_ratings: 1000 }])

      imported = @importer.import_from_search("Unpopular")

      assert_empty imported
      @client.verify
    end

    test "import_from_search only imports first 20 results" do
      items = (1..25).map { |i| { id: i.to_s, type: "boardgame", name: "Game #{i}" } }
      search_results = { total: 25, items: items }

      game_details = (1..20).map do |i|
        {
          id: i,
          thing_type: "boardgame",
          name: "Game #{i}",
          year_published: 2020,
          min_players: 2,
          max_players: 4,
          min_playing_time: 30,
          max_playing_time: 60,
          playing_time: 45,
          rating: 7.0,
          complexity: 2.0,
          user_ratings_count: 10000,
          categories: [],
          mechanics: []
        }
      end

      @client.expect(:search, search_results, ["Popular"])
      @client.expect(:get_details, game_details, [(1..20).to_a, { min_user_ratings: 1000 }])

      imported = @importer.import_from_search("Popular")

      assert_equal 20, imported.length
      @client.verify
    end

    test "import_from_search with dry_run does not persist records" do
      search_results = {
        total: 1,
        items: [{ id: "13", type: "boardgame", name: "Catan", year_published: "1995" }]
      }

      game_details = [{
        id: 13,
        thing_type: "boardgame",
        name: "Catan",
        year_published: 1995,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        playing_time: 120,
        rating: 7.12,
        complexity: 2.35,
        user_ratings_count: 50000,
        categories: ["Economic"],
        mechanics: ["Trading"]
      }]

      @client.expect(:search, search_results, ["Catan"])
      @client.expect(:get_details, game_details, [[13], { min_user_ratings: 1000 }])

      initial_count = BoardGame.count
      imported = @importer.import_from_search("Catan", dry_run: true)

      assert_equal 1, imported.length
      assert_equal "Catan", imported[0].name
      assert_not imported[0].persisted?
      assert_equal initial_count, BoardGame.count

      @client.verify
    end

    test "import_from_search raises ImportError on client error" do
      # Define a method on the mock that raises an error
      def @client.search(_query)
        raise BggApi::Client::TimeoutError, "Timeout"
      end

      error = assert_raises(BggApi::GameImporter::ImportError) do
        @importer.import_from_search("Catan")
      end

      assert_match(/Failed to import games from BGG/, error.message)
    end

    # Tests for import_by_id

    test "import_by_id imports a single board game" do
      game_details = [{
        id: 13,
        thing_type: "boardgame",
        name: "Catan",
        year_published: 1995,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        playing_time: 120,
        rating: 7.12,
        complexity: 2.35,
        user_ratings_count: 50000,
        categories: ["Economic"],
        mechanics: ["Trading"]
      }]

      @client.expect(:get_details, game_details, [[13], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(13)

      assert_not_nil imported
      assert_equal "Catan", imported.name
      assert_equal 1995, imported.year_published
      assert imported.persisted?

      @client.verify
    end

    test "import_by_id returns nil when game not found" do
      @client.expect(:get_details, [], [[99999], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(99999)

      assert_nil imported
      @client.verify
    end

    test "import_by_id with dry_run does not persist" do
      game_details = [{
        id: 13,
        thing_type: "boardgame",
        name: "Catan",
        year_published: 1995,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        playing_time: 120,
        rating: 7.12,
        complexity: 2.35,
        user_ratings_count: 50000,
        categories: [],
        mechanics: []
      }]

      @client.expect(:get_details, game_details, [[13], { min_user_ratings: 0 }])

      initial_count = BoardGame.count
      imported = @importer.import_by_id(13, dry_run: true)

      assert_not_nil imported
      assert_not imported.persisted?
      assert_equal initial_count, BoardGame.count

      @client.verify
    end

    test "import_by_id raises ImportError on client error" do
      # Define a method on the mock that raises an error
      def @client.get_details(_ids, _options)
        raise BggApi::Client::ApiError, "API Error"
      end

      error = assert_raises(BggApi::GameImporter::ImportError) do
        @importer.import_by_id(13)
      end

      assert_match(/Failed to import game 13 from BGG/, error.message)
    end

    # Tests for importing board games

    test "import creates board game with all attributes" do
      game_data = {
        id: 13,
        thing_type: "boardgame",
        types: %w[strategy family],
        name: "Catan",
        year_published: 1995,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        playing_time: 120,
        rating: 7.12,
        complexity: 2.35,
        user_ratings_count: 50000,
        categories: %w[Economic Negotiation],
        mechanics: ["Dice Rolling", "Trading"]
      }

      @client.expect(:get_details, [game_data], [[13], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(13)

      assert_equal "Catan", imported.name
      assert_equal 1995, imported.year_published
      assert_equal 3, imported.min_players
      assert_equal 4, imported.max_players
      assert_equal 60, imported.min_playing_time
      assert_equal 120, imported.max_playing_time
      assert_equal 7.12, imported.rating
      assert_equal 2.35, imported.difficulty_score

      # Check associations
      assert_equal 2, imported.game_categories.count
      assert_includes imported.game_categories.map(&:name), "Economic"
      assert_includes imported.game_categories.map(&:name), "Negotiation"

      assert_equal 2, imported.game_types.count
      assert_includes imported.game_types.map(&:name), "strategy"
      assert_includes imported.game_types.map(&:name), "family"

      # Check BGG association
      assert_not_nil imported.bgg_board_game_association
      assert_equal 13, imported.bgg_board_game_association.bgg_id

      @client.verify
    end

    test "import creates default game type and category when empty" do
      game_data = {
        id: 13,
        thing_type: "boardgame",
        name: "Test Game",
        year_published: 2020,
        min_players: 2,
        max_players: 4,
        min_playing_time: 30,
        max_playing_time: 60,
        playing_time: 45,
        rating: 7.0,
        complexity: 2.0,
        user_ratings_count: 10000,
        categories: [],
        mechanics: []
      }

      @client.expect(:get_details, [game_data], [[13], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(13)

      assert_equal 1, imported.game_categories.count
      assert_equal "General", imported.game_categories.first.name

      assert_equal 1, imported.game_types.count
      assert_equal "General", imported.game_types.first.name

      @client.verify
    end

    test "import does not create duplicate when already imported" do
      game_data = {
        id: 13,
        thing_type: "boardgame",
        name: "Catan",
        year_published: 1995,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        playing_time: 120,
        rating: 7.12,
        complexity: 2.35,
        user_ratings_count: 50000,
        categories: ["Economic"],
        mechanics: ["Trading"]
      }

      @client.expect(:get_details, [game_data], [[13], { min_user_ratings: 0 }])
      first_import = @importer.import_by_id(13)

      @client.expect(:get_details, [game_data], [[13], { min_user_ratings: 0 }])
      second_import = @importer.import_by_id(13)

      assert_equal first_import.id, second_import.id
      # Check that only one BGG association was created for this BGG ID
      assert_equal 1, BggBoardGameAssociation.where(bgg_id: 13).count

      @client.verify
    end

    # Tests for importing extensions

    test "import creates extension with parent game" do
      # First create parent game
      parent_game = BoardGame.create!(
        name: "Catan",
        year_published: 1995,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        rating: 7.12,
        difficulty_score: 2.35,
        game_types: [GameType.find_or_create_by!(name: "General")],
        game_categories: [GameCategory.find_or_create_by!(name: "General")]
      )
      parent_game.create_bgg_board_game_association!(bgg_id: 13)

      extension_data = {
        id: 12345,
        thing_type: "boardgameexpansion",
        name: "Catan: Seafarers",
        year_published: 1997,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        playing_time: 90,
        rating: 7.0,
        complexity: 2.4,
        user_ratings_count: 25000,
        categories: ["Exploration"],
        mechanics: ["Modular Board"],
        parent_game_ids: [13]
      }

      @client.expect(:get_details, [extension_data], [[12345], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(12345)

      assert_not_nil imported
      assert_equal "Catan: Seafarers", imported.name
      assert_equal parent_game.id, imported.board_game_id
      assert_equal 1997, imported.year_published
      assert imported.persisted?

      # Check BGG association
      assert_not_nil imported.bgg_extension_association
      assert_equal 12345, imported.bgg_extension_association.bgg_id

      @client.verify
    end

    test "import skips extension when parent game not found" do
      extension_data = {
        id: 12345,
        thing_type: "boardgameexpansion",
        name: "Catan: Seafarers",
        year_published: 1997,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        playing_time: 90,
        rating: 7.0,
        complexity: 2.4,
        user_ratings_count: 25000,
        categories: [],
        mechanics: [],
        parent_game_ids: [13]  # Parent not in database
      }

      @client.expect(:get_details, [extension_data], [[12345], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(12345)

      assert_nil imported

      @client.verify
    end

    test "import raises error for extension without parent game IDs" do
      extension_data = {
        id: 12345,
        thing_type: "boardgameexpansion",
        name: "Orphan Extension",
        year_published: 2020,
        min_players: 2,
        max_players: 4,
        min_playing_time: 30,
        max_playing_time: 60,
        playing_time: 45,
        rating: 7.0,
        complexity: 2.0,
        user_ratings_count: 10000,
        categories: [],
        mechanics: [],
        parent_game_ids: []
      }

      @client.expect(:get_details, [extension_data], [[12345], { min_user_ratings: 0 }])

      error = assert_raises(BggApi::GameImporter::ImportError) do
        @importer.import_by_id(12345)
      end

      assert_match(/Extension 12345 has no parent games/, error.message)
    end

    test "import raises error for unknown game type" do
      unknown_data = {
        id: 99999,
        thing_type: "unknowntype",
        name: "Unknown Type",
        year_published: 2020,
        min_players: 2,
        max_players: 4,
        min_playing_time: 30,
        max_playing_time: 60,
        playing_time: 45,
        rating: 7.0,
        complexity: 2.0,
        user_ratings_count: 10000,
        categories: [],
        mechanics: []
      }

      @client.expect(:get_details, [unknown_data], [[99999], { min_user_ratings: 0 }])

      error = assert_raises(BggApi::GameImporter::ImportError) do
        @importer.import_by_id(99999)
      end

      assert_match(/Unknown game type: unknowntype/, error.message)
    end
  end
end