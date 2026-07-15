require "test_helper"

module BoardGames
  module Details
    class SerializerTest < ActiveSupport::TestCase
      setup do
        @board_game = board_games(:catan)
        @serializer = BoardGames::Details::Serializer.new
      end

      test "serialize returns hash with all required fields including expansions" do
        result = @serializer.serialize(@board_game)

        required_fields = [:id, :name, :year_published, :game_types, :game_categories, :min_players,
                          :max_players, :min_playing_time, :max_playing_time,
                          :rating, :rating_count, :difficulty_score, :expansions]

        required_fields.each do |field|
          assert_includes result, field, "Result should include #{field}"
        end
      end

      test "serialize returns correct data types" do
        result = @serializer.serialize(@board_game)

        assert_instance_of Integer, result[:id]
        assert_instance_of String, result[:name]
        assert_instance_of Array, result[:game_types]
        assert_instance_of Array, result[:game_categories]
        assert_instance_of Integer, result[:min_players]
        assert_instance_of Integer, result[:max_players]
        assert_instance_of Array, result[:expansions]
      end

      test "serialize includes expansions data" do
        # Create an expansion for the board game
        game_type = GameType.first || GameType.create!(name: "Strategy")
        game_category = GameCategory.first || GameCategory.create!(name: "Economic")

        expansion = BoardGame.create!(
          name: "Test Expansion",
          year_published: 2021,
          min_players: 3,
          max_players: 5,
          game_types: [game_type],
          game_categories: [game_category]
        )

        BoardGameRelation.create!(
          source_game: expansion,
          target_game: @board_game,
          relation_type: :expands
        )

        result = @serializer.serialize(@board_game)
        expansions = result[:expansions]

        assert expansions.is_a?(Array)
        assert expansions.any?

        expansion_data = expansions.first
        required_expansion_fields = [:id, :name, :year_published, :min_players, :max_players,
                                     :min_playing_time, :max_playing_time,
                                     :rating, :rating_count, :difficulty_score]

        required_expansion_fields.each do |field|
          assert_includes expansion_data, field, "Expansion should include #{field}"
        end
      end

      test "serialize sorts expansions by recommended score, not insertion order" do
        game_type = GameType.first || GameType.create!(name: "Strategy")
        game_category = GameCategory.first || GameCategory.create!(name: "Economic")

        # Inserted noisy-first: a 9.5/10 with a handful of ratings should NOT
        # outrank a slightly-lower rating backed by thousands of ratings.
        noisy = BoardGame.create!(
          name: "Noisy Expansion", year_published: 2022,
          min_players: 2, max_players: 4, rating: 9.5, rating_count: 3,
          game_types: [game_type], game_categories: [game_category]
        )
        beloved = BoardGame.create!(
          name: "Beloved Expansion", year_published: 2018,
          min_players: 2, max_players: 4, rating: 8.5, rating_count: 5000,
          game_types: [game_type], game_categories: [game_category]
        )

        [noisy, beloved].each do |exp|
          BoardGameRelation.create!(source_game: exp, target_game: @board_game, relation_type: :expands)
        end

        result = BoardGames::Details::Serializer.serialize(@board_game.reload)
        names = result[:expansions].map { |e| e[:name] }

        assert_equal ["Beloved Expansion", "Noisy Expansion"], names.first(2)
      end

      test "serialize breaks expansion ties by newest year when all unrated" do
        game_type = GameType.first || GameType.create!(name: "Strategy")
        game_category = GameCategory.first || GameCategory.create!(name: "Economic")

        older = BoardGame.create!(
          name: "Older Unrated", year_published: 2015,
          min_players: 2, max_players: 4,
          game_types: [game_type], game_categories: [game_category]
        )
        newer = BoardGame.create!(
          name: "Newer Unrated", year_published: 2021,
          min_players: 2, max_players: 4,
          game_types: [game_type], game_categories: [game_category]
        )

        # Insert older-first so a stable sort wouldn't reorder on its own.
        [older, newer].each do |exp|
          BoardGameRelation.create!(source_game: exp, target_game: @board_game, relation_type: :expands)
        end

        result = BoardGames::Details::Serializer.serialize(@board_game.reload)
        names = result[:expansions].map { |e| e[:name] }

        assert_equal ["Newer Unrated", "Older Unrated"], names.first(2)
      end

      test "serialize handles board game without expansions" do
        game_type = GameType.create!(name: "test_type")
        game_category = GameCategory.create!(name: "test_category")

        board_game_without_expansions = BoardGame.create!(
          name: "Test Game",
          year_published: 2020,
          min_players: 1,
          max_players: 4,
          min_playing_time: 30,
          max_playing_time: 60,
          rating: 7.5,
          difficulty_score: 3.0,
          game_types: [game_type],
          game_categories: [game_category]
        )

        result = @serializer.serialize(board_game_without_expansions)

        assert_equal [], result[:expansions]
      end

      test "serialize class method delegates to instance" do
        result = BoardGames::Details::Serializer.serialize(@board_game)

        assert_instance_of Hash, result
        assert_equal @board_game.id, result[:id]
        assert_includes result, :expansions
      end

      test "serialize returns all relation arrays" do
        result = @serializer.serialize(@board_game)

        BoardGames::Details::Serializer::RELATION_KEYS.each do |key|
          assert_includes result, key, "Result should include #{key}"
          assert_instance_of Array, result[key]
        end
      end

      test "serialize populates each relation type from board_game_relations" do
        game_type = GameType.first || GameType.create!(name: "Strategy")
        game_category = GameCategory.first || GameCategory.create!(name: "Economic")

        related = {}
        BoardGames::Details::Serializer::RELATION_KEYS.each_with_index do |key, idx|
          related[key] = BoardGame.create!(
            name: "Related #{key} #{idx}",
            year_published: 2000 + idx,
            min_players: 2,
            max_players: 4,
            game_types: [game_type],
            game_categories: [game_category]
          )
        end

        # expansions: source expands target(@board_game)
        BoardGameRelation.create!(source_game: related[:expansions], target_game: @board_game, relation_type: :expands)
        # base_games: @board_game expands target
        BoardGameRelation.create!(source_game: @board_game, target_game: related[:base_games], relation_type: :expands)
        # contained_games: @board_game contains target
        BoardGameRelation.create!(source_game: @board_game, target_game: related[:contained_games], relation_type: :contains)
        # containers: source contains @board_game
        BoardGameRelation.create!(source_game: related[:containers], target_game: @board_game, relation_type: :contains)
        # reimplemented_games: @board_game reimplements target
        BoardGameRelation.create!(source_game: @board_game, target_game: related[:reimplemented_games], relation_type: :reimplements)
        # reimplementations: source reimplements @board_game
        BoardGameRelation.create!(source_game: related[:reimplementations], target_game: @board_game, relation_type: :reimplements)
        # integrated_games: @board_game integrates_with target
        BoardGameRelation.create!(source_game: @board_game, target_game: related[:integrated_games], relation_type: :integrates_with)

        result = BoardGames::Details::Serializer.serialize(@board_game.reload)

        BoardGames::Details::Serializer::RELATION_KEYS.each do |key|
          assert_equal [related[key].id], result[key].map { |g| g[:id] }, "Wrong contents for #{key}"
        end
      end
    end
  end
end
