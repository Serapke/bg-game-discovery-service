require "test_helper"

module BoardGames
  class SerializerTest < ActiveSupport::TestCase
    setup do
      @board_game = board_games(:catan)
      @serializer = BoardGames::Serializer.new
    end

    test "serialize returns hash with all required fields" do
      result = @serializer.serialize(@board_game)

      required_fields = [:id, :name, :year_published, :game_types, :game_categories, :min_players,
                        :max_players, :min_playing_time, :max_playing_time,
                        :rating, :difficulty_score, :extensions]

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
      assert_instance_of Array, result[:extensions]
    end

    test "serialize includes game type names as strings" do
      result = @serializer.serialize(@board_game)

      assert result[:game_types].is_a?(Array)
      assert result[:game_types].all? { |type| type.is_a?(String) }
      assert result[:game_types].any?
    end

    test "serialize includes game category names as strings" do
      result = @serializer.serialize(@board_game)

      assert result[:game_categories].is_a?(Array)
      assert result[:game_categories].all? { |cat| cat.is_a?(String) }
      assert result[:game_categories].any?
    end

    test "serialize includes extension data" do
      result = @serializer.serialize(@board_game)
      extensions = result[:extensions]

      assert extensions.is_a?(Array)

      if extensions.any?
        extension = extensions.first
        required_extension_fields = [:id, :name, :year_published, :min_players, :max_players,
                                     :min_playing_time, :max_playing_time,
                                     :rating, :difficulty_score]

        required_extension_fields.each do |field|
          assert_includes extension, field, "Extension should include #{field}"
        end
      end
    end

    test "serialize_collection returns hash with board_games and total" do
      board_games = BoardGame.limit(2)
      result = @serializer.serialize_collection(board_games)

      assert_includes result, :board_games
      assert_includes result, :total
    end

    test "serialize_collection returns correct total count" do
      board_games = BoardGame.limit(2)
      result = @serializer.serialize_collection(board_games)

      assert_equal 2, result[:total]
    end

    test "serialize_collection serializes all board games" do
      board_games = BoardGame.limit(2)
      result = @serializer.serialize_collection(board_games)

      assert_equal 2, result[:board_games].length
      assert result[:board_games].all? { |game| game.is_a?(Hash) }
      assert result[:board_games].all? { |game| game.key?(:id) }
    end

    test "serialize class method delegates to instance" do
      result = BoardGames::Serializer.serialize(@board_game)

      assert_instance_of Hash, result
      assert_equal @board_game.id, result[:id]
    end

    test "serialize_collection class method delegates to instance" do
      board_games = BoardGame.limit(2)
      result = BoardGames::Serializer.serialize_collection(board_games)

      assert_instance_of Hash, result
      assert_includes result, :board_games
      assert_includes result, :total
    end

    test "serialize handles board game without extensions" do
      game_type = GameType.create!(name: "test_type")
      game_category = GameCategory.create!(name: "test_category")

      board_game_without_extensions = BoardGame.create!(
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

      result = @serializer.serialize(board_game_without_extensions)

      assert_equal [], result[:extensions]
    end
  end
end