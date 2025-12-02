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
                        :rating, :difficulty_score]

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

  end
end