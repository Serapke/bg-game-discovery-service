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
          types: [{ name: "strategy", rank: 100 }, { name: "family", rank: 50 }],
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
          types: [{ name: "strategy", rank: 75 }],
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
        types: [{ name: "strategy", rank: 100 }, { name: "family", rank: 50 }],
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
          types: [{ name: "strategy", rank: 75 }],
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
        types: [{ name: "strategy", rank: 100 }, { name: "family", rank: 50 }],
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
        types: [{ name: "strategy", rank: 100 }, { name: "family", rank: 50 }],
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

    test "import creates expansion with parent game" do
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

      expansion_data = {
        id: 12345,
        thing_type: "boardgameexpansion",
        types: [{ name: "strategy", rank: 100 }],
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
        links: { expands: [13], contains: [], reimplements: [], reimplemented_by: [] }
      }

      @client.expect(:get_details, [expansion_data], [[12345], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(12345)

      assert_not_nil imported
      assert_instance_of BoardGame, imported
      assert_equal "Catan: Seafarers", imported.name
      assert_equal 1997, imported.year_published
      assert imported.persisted?

      # Check BGG association
      assert_not_nil imported.bgg_board_game_association
      assert_equal 12345, imported.bgg_board_game_association.bgg_id

      # Check expansion relationship
      relation = BoardGameRelation.find_by(source_game: imported, target_game: parent_game)
      assert_not_nil relation
      assert_equal "expands", relation.relation_type

      # Check it appears in parent's expansions
      assert_includes parent_game.expansions, imported

      @client.verify
    end

    test "import creates expansion without relation when parent game not found" do
      expansion_data = {
        id: 12345,
        thing_type: "boardgameexpansion",
        types: [{ name: "strategy", rank: 100 }],
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
        mechanics: [],
        links: { expands: [13], contains: [], reimplements: [], reimplemented_by: [] }  # Parent not in database
      }

      @client.expect(:get_details, [expansion_data], [[12345], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(12345)

      # Expansion is still imported as a BoardGame, just without the relation
      assert_not_nil imported
      assert_instance_of BoardGame, imported
      assert_equal "Catan: Seafarers", imported.name

      # But no relation was created
      assert_equal 0, BoardGameRelation.where(source_game: imported).count

      @client.verify
    end

    test "import creates expansion without relation when parent game IDs empty" do
      expansion_data = {
        id: 12345,
        thing_type: "boardgameexpansion",
        types: [{ name: "strategy", rank: 100 }],
        name: "Orphan Expansion",
        year_published: 2020,
        min_players: 2,
        max_players: 4,
        min_playing_time: 30,
        max_playing_time: 60,
        playing_time: 45,
        rating: 7.0,
        complexity: 2.0,
        user_ratings_count: 10000,
        categories: ["Adventure"],
        mechanics: [],
        links: { expands: [], contains: [], reimplements: [], reimplemented_by: [] }
      }

      @client.expect(:get_details, [expansion_data], [[12345], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(12345)

      # Expansion is imported as a BoardGame without any relation
      assert_not_nil imported
      assert_instance_of BoardGame, imported
      assert_equal "Orphan Expansion", imported.name
      assert_equal 0, BoardGameRelation.where(source_game: imported).count

      @client.verify
    end

    test "import creates compilation with contained games" do
      # Create contained games
      contained_game_1 = BoardGame.create!(
        name: "Game 1",
        year_published: 2010,
        min_players: 2,
        max_players: 4,
        min_playing_time: 30,
        max_playing_time: 60,
        rating: 7.0,
        difficulty_score: 2.0,
        game_types: [GameType.find_or_create_by!(name: "General")],
        game_categories: [GameCategory.find_or_create_by!(name: "General")]
      )
      contained_game_1.create_bgg_board_game_association!(bgg_id: 100)

      contained_game_2 = BoardGame.create!(
        name: "Game 2",
        year_published: 2012,
        min_players: 2,
        max_players: 4,
        min_playing_time: 45,
        max_playing_time: 90,
        rating: 7.5,
        difficulty_score: 2.5,
        game_types: [GameType.find_or_create_by!(name: "General")],
        game_categories: [GameCategory.find_or_create_by!(name: "General")]
      )
      contained_game_2.create_bgg_board_game_association!(bgg_id: 200)

      compilation_data = {
        id: 54321,
        thing_type: "boardgame",
        types: [{ name: "strategy", rank: 50 }],
        name: "Big Box Collection",
        year_published: 2020,
        min_players: 2,
        max_players: 4,
        min_playing_time: 30,
        max_playing_time: 90,
        playing_time: 60,
        rating: 7.8,
        complexity: 2.3,
        user_ratings_count: 15000,
        categories: ["Collection"],
        mechanics: [],
        links: { expands: [], contains: [100, 200], reimplements: [], reimplemented_by: [] }
      }

      @client.expect(:get_details, [compilation_data], [[54321], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(54321)

      assert_not_nil imported
      assert_instance_of BoardGame, imported
      assert_equal "Big Box Collection", imported.name
      assert imported.persisted?

      # Check compilation relationships
      relation_1 = BoardGameRelation.find_by(source_game: imported, target_game: contained_game_1)
      assert_not_nil relation_1
      assert_equal "contains", relation_1.relation_type

      relation_2 = BoardGameRelation.find_by(source_game: imported, target_game: contained_game_2)
      assert_not_nil relation_2
      assert_equal "contains", relation_2.relation_type

      # Check it appears in contained games' containers
      assert_includes contained_game_1.containers, imported
      assert_includes contained_game_2.containers, imported

      @client.verify
    end

    test "import creates compilation without relations when contained games not found" do
      compilation_data = {
        id: 54321,
        thing_type: "boardgame",
        types: [{ name: "strategy", rank: 50 }],
        name: "Big Box Collection",
        year_published: 2020,
        min_players: 2,
        max_players: 4,
        min_playing_time: 30,
        max_playing_time: 90,
        playing_time: 60,
        rating: 7.8,
        complexity: 2.3,
        user_ratings_count: 15000,
        categories: ["Collection"],
        mechanics: [],
        links: { expands: [], contains: [100, 200], reimplements: [], reimplemented_by: [] }  # Games not in database
      }

      @client.expect(:get_details, [compilation_data], [[54321], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(54321)

      # Compilation is still imported, just without relations
      assert_not_nil imported
      assert_instance_of BoardGame, imported
      assert_equal "Big Box Collection", imported.name

      # No relations were created
      assert_equal 0, BoardGameRelation.where(source_game: imported, relation_type: "contains").count

      @client.verify
    end

    test "import creates reimplementation with reimplemented games" do
      # Create original game
      original_game = BoardGame.create!(
        name: "Carcassonne",
        year_published: 2000,
        min_players: 2,
        max_players: 5,
        min_playing_time: 30,
        max_playing_time: 45,
        rating: 7.4,
        difficulty_score: 1.9,
        game_types: [GameType.find_or_create_by!(name: "General")],
        game_categories: [GameCategory.find_or_create_by!(name: "General")]
      )
      original_game.create_bgg_board_game_association!(bgg_id: 822)

      reimplementation_data = {
        id: 230914,
        thing_type: "boardgame",
        types: [{ name: "family", rank: 75 }],
        name: "Carcassonne Big Box 6",
        year_published: 2017,
        min_players: 2,
        max_players: 5,
        min_playing_time: 30,
        max_playing_time: 45,
        playing_time: 45,
        rating: 7.5,
        complexity: 1.9,
        user_ratings_count: 5000,
        categories: ["Medieval"],
        mechanics: ["Tile Placement"],
        links: { expands: [], contains: [], reimplements: [822], reimplemented_by: [] }
      }

      @client.expect(:get_details, [reimplementation_data], [[230914], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(230914)

      assert_not_nil imported
      assert_instance_of BoardGame, imported
      assert_equal "Carcassonne Big Box 6", imported.name
      assert imported.persisted?

      # Check reimplementation relationship
      relation = BoardGameRelation.find_by(source_game: imported, target_game: original_game)
      assert_not_nil relation
      assert_equal "reimplements", relation.relation_type

      # Check it appears in original's reimplementations
      assert_includes original_game.reimplementations, imported

      # Check original appears in reimplementation's reimplemented_games
      assert_includes imported.reimplemented_games, original_game

      @client.verify
    end

    test "import creates game with reimplemented_by links" do
      # Create reimplementation games
      reimplementation_1 = BoardGame.create!(
        name: "Carcassonne Big Box 6",
        year_published: 2017,
        min_players: 2,
        max_players: 5,
        min_playing_time: 30,
        max_playing_time: 45,
        rating: 7.5,
        difficulty_score: 1.9,
        game_types: [GameType.find_or_create_by!(name: "General")],
        game_categories: [GameCategory.find_or_create_by!(name: "General")]
      )
      reimplementation_1.create_bgg_board_game_association!(bgg_id: 230914)

      reimplementation_2 = BoardGame.create!(
        name: "Carcassonne Big Box 7",
        year_published: 2020,
        min_players: 2,
        max_players: 5,
        min_playing_time: 30,
        max_playing_time: 45,
        rating: 7.6,
        difficulty_score: 1.9,
        game_types: [GameType.find_or_create_by!(name: "General")],
        game_categories: [GameCategory.find_or_create_by!(name: "General")]
      )
      reimplementation_2.create_bgg_board_game_association!(bgg_id: 364405)

      original_data = {
        id: 822,
        thing_type: "boardgame",
        types: [{ name: "family", rank: 50 }],
        name: "Carcassonne",
        year_published: 2000,
        min_players: 2,
        max_players: 5,
        min_playing_time: 30,
        max_playing_time: 45,
        playing_time: 45,
        rating: 7.4,
        complexity: 1.9,
        user_ratings_count: 75000,
        categories: ["Medieval"],
        mechanics: ["Tile Placement"],
        links: { expands: [], contains: [], reimplements: [], reimplemented_by: [230914, 364405] }
      }

      @client.expect(:get_details, [original_data], [[822], { min_user_ratings: 0 }])

      imported = @importer.import_by_id(822)

      assert_not_nil imported
      assert_instance_of BoardGame, imported
      assert_equal "Carcassonne", imported.name
      assert imported.persisted?

      # Check reversed reimplementation relationships were created correctly
      relation_1 = BoardGameRelation.find_by(source_game: reimplementation_1, target_game: imported)
      assert_not_nil relation_1
      assert_equal "reimplements", relation_1.relation_type

      relation_2 = BoardGameRelation.find_by(source_game: reimplementation_2, target_game: imported)
      assert_not_nil relation_2
      assert_equal "reimplements", relation_2.relation_type

      # Check bidirectional relationships work
      assert_includes imported.reimplementations, reimplementation_1
      assert_includes imported.reimplementations, reimplementation_2
      assert_includes reimplementation_1.reimplemented_games, imported
      assert_includes reimplementation_2.reimplemented_games, imported

      @client.verify
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