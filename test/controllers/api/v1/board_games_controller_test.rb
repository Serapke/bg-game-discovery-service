require "test_helper"

class Api::V1::BoardGamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @board_game = board_games(:catan)
  end

  test "should get index of all board games" do
    get api_v1_board_games_url
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_includes json_response, "board_games"
    assert_includes json_response, "total"
    assert_equal BoardGame.count, json_response["total"]
    assert_equal BoardGame.count, json_response["board_games"].length

    # Verify each game has game_types and game_categories
    json_response["board_games"].each do |game|
      assert_includes game, "game_types"
      assert_includes game, "game_categories"
      assert game["game_types"].is_a?(Array)
      assert game["game_categories"].is_a?(Array)
    end
  end

  test "should get index with valid IDs parameter" do
    board_game1 = board_games(:catan)
    board_game2 = board_games(:wingspan)

    get api_v1_board_games_url, params: { ids: "#{board_game1.id},#{board_game2.id}" }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_includes json_response, "board_games"
    assert_includes json_response, "total"
    assert_equal 2, json_response["total"]
    assert_equal 2, json_response["board_games"].length

    game_ids = json_response["board_games"].map { |g| g["id"] }
    assert_includes game_ids, board_game1.id
    assert_includes game_ids, board_game2.id
  end

  test "should return bad request for invalid IDs parameter" do
    get api_v1_board_games_url, params: { ids: "invalid,abc,0" }
    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal "No valid IDs provided", json_response["error"]
  end

  test "should return bad request for empty IDs parameter" do
    get api_v1_board_games_url, params: { ids: "" }
    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal "No valid IDs provided", json_response["error"]
  end

  test "should show board game" do
    get api_v1_board_game_url(@board_game)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @board_game.id, json_response["id"]
    assert_equal @board_game.name, json_response["name"]
    assert_equal @board_game.min_players, json_response["min_players"]
    assert_equal @board_game.max_players, json_response["max_players"]
    assert_equal @board_game.rating.to_s, json_response["rating"]
    assert_includes json_response, "extensions"
  end

  test "should return 404 for non-existent board game" do
    get api_v1_board_game_url(99999)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal "Board game not found", json_response["error"]
  end

  test "should include extensions in show response" do
    get api_v1_board_game_url(@board_game)
    assert_response :success

    json_response = JSON.parse(response.body)
    extensions = json_response["extensions"]

    assert extensions.is_a?(Array)
    assert extensions.length > 0

    extension = extensions.first
    assert_includes extension, "id"
    assert_includes extension, "name"
    assert_includes extension, "min_players"
    assert_includes extension, "max_players"
    assert_includes extension, "rating"
  end

  test "should search all board games when no parameters" do
    get search_api_v1_board_games_url
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_includes json_response, "board_games"
    assert_includes json_response, "total"
    assert_equal BoardGame.count, json_response["total"]
  end

  test "should search board games by name" do
    get search_api_v1_board_games_url, params: { name: "catan" }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    assert board_games.length > 0
    assert board_games.any? { |game| game["name"].downcase.include?("catan") }
    assert_equal board_games.length, json_response["total"]
  end

  test "should search board games by name case insensitive" do
    get search_api_v1_board_games_url, params: { name: "CATAN" }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    assert board_games.length > 0
    assert board_games.any? { |game| game["name"].downcase.include?("catan") }
  end

  test "should filter board games by player count" do
    get search_api_v1_board_games_url, params: { player_count: 3 }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    board_games.each do |game|
      assert game["min_players"] <= 3
      assert game["max_players"] >= 3
    end
  end

  test "should filter board games by single player" do
    get search_api_v1_board_games_url, params: { player_count: 1 }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    board_games.each do |game|
      assert game["min_players"] <= 1
      assert game["max_players"] >= 1
    end
  end

  test "should combine name and player count filters" do
    get search_api_v1_board_games_url, params: { name: "wing", player_count: 2 }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    board_games.each do |game|
      assert game["name"].downcase.include?("wing")
      assert game["min_players"] <= 2
      assert game["max_players"] >= 2
    end
  end

  test "should return empty results for non-matching search" do
    # Stub BGG API to return empty results
    stub_request(:get, "https://boardgamegeek.com/xmlapi2/search").
      with(query: hash_including(query: "nonexistentgame")).
      to_return(status: 200, body: '<?xml version="1.0" encoding="utf-8"?><items total="0"></items>', headers: {})

    get search_api_v1_board_games_url, params: { name: "nonexistentgame" }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal [], json_response["board_games"]
    assert_equal 0, json_response["total"]
  end

  test "should return bad request for empty name parameter" do
    get search_api_v1_board_games_url, params: { name: "" }
    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal "Name parameter cannot be empty", json_response["error"]
  end

  test "should filter board games by exact playing time" do
    get search_api_v1_board_games_url, params: { playing_time: 70 }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    board_games.each do |game|
      assert game["min_playing_time"] <= 70
      assert game["max_playing_time"] >= 70
    end
  end

  test "should filter board games by maximum playing time" do
    get search_api_v1_board_games_url, params: { max_playing_time: 50 }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    board_games.each do |game|
      assert game["max_playing_time"] <= 50
    end
  end

  test "should filter board games by minimum playing time" do
    get search_api_v1_board_games_url, params: { min_playing_time: 50 }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    board_games.each do |game|
      assert game["min_playing_time"] >= 50
    end
  end

  test "should combine multiple playing time filters" do
    get search_api_v1_board_games_url, params: { min_playing_time: 30, max_playing_time: 60 }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    board_games.each do |game|
      assert game["min_playing_time"] >= 30
      assert game["max_playing_time"] <= 60
    end
  end

  test "should combine all search filters including playing time" do
    get search_api_v1_board_games_url, params: {
      name: "wing",
      player_count: 2,
      playing_time: 50
    }
    assert_response :success

    json_response = JSON.parse(response.body)
    board_games = json_response["board_games"]

    board_games.each do |game|
      assert game["name"].downcase.include?("wing")
      assert game["min_players"] <= 2
      assert game["max_players"] >= 2
      assert game["min_playing_time"] <= 50
      assert game["max_playing_time"] >= 50
    end
  end

  test "should return properly formatted board game JSON" do
    get api_v1_board_game_url(@board_game)
    assert_response :success

    json_response = JSON.parse(response.body)

    required_fields = %w[id name game_types game_categories min_players max_players min_playing_time max_playing_time rating extensions]
    required_fields.each do |field|
      assert_includes json_response, field, "Response should include #{field}"
    end

    # Verify game_types is an array and contains strings
    assert json_response["game_types"].is_a?(Array), "game_types should be an array"
    assert json_response["game_types"].all? { |type| type.is_a?(String) }, "game_types should contain strings"
    assert json_response["game_types"].any?, "game_types should not be empty"

    # Verify game_categories is an array and contains strings
    assert json_response["game_categories"].is_a?(Array), "game_categories should be an array"
    assert json_response["game_categories"].all? { |cat| cat.is_a?(String) }, "game_categories should contain strings"
    assert json_response["game_categories"].any?, "game_categories should not be empty"

    extensions = json_response["extensions"]
    if extensions.any?
      extension = extensions.first
      extension_fields = %w[id name min_players max_players min_playing_time max_playing_time rating]
      extension_fields.each do |field|
        assert_includes extension, field, "Extension should include #{field}"
      end
    end
  end
end