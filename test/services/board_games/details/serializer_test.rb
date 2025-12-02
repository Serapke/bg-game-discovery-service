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
    end
  end
end
