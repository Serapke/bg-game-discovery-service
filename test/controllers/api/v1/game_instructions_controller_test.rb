require "test_helper"

class Api::V1::GameInstructionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @board_game = board_games(:catan)
  end

  def upload(filename: "sample.pdf", content_type: "application/pdf")
    fixture_file_upload(filename, content_type)
  end

  def create_instruction!(language: "en", category: "manual")
    @board_game.game_instructions.create!(language: language, category: category) do |i|
      i.document.attach(io: file_fixture("sample.pdf").open, filename: "sample.pdf", content_type: "application/pdf")
    end
  end

  test "index lists a game's instructions" do
    instruction = create_instruction!
    get api_v1_board_game_instructions_url(@board_game)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    assert_equal instruction.id, body.first["id"]
    assert_equal "en", body.first["language"]
    assert_equal "manual", body.first["category"]
    assert body.first["url"].present?
  end

  test "index returns 404 for an unknown game" do
    get api_v1_board_game_instructions_url(board_game_id: 0)
    assert_response :not_found
  end

  test "create uploads an instruction" do
    assert_difference -> { @board_game.game_instructions.count }, 1 do
      post api_v1_board_game_instructions_url(@board_game),
        params: { document: upload, language: "en", category: "manual" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["id"].present?
    assert body["url"].present?
  end

  test "create rejects a non-PDF file" do
    assert_no_difference -> { @board_game.game_instructions.count } do
      post api_v1_board_game_instructions_url(@board_game),
        params: { document: upload(filename: "sample.txt", content_type: "text/plain"),
                  language: "en", category: "manual" }
    end

    assert_response :unprocessable_entity
  end

  test "create without a document returns bad request" do
    post api_v1_board_game_instructions_url(@board_game), params: { language: "en", category: "manual" }
    assert_response :bad_request
  end

  test "create returns conflict for a duplicate game + language + category" do
    create_instruction!(language: "en", category: "manual")

    assert_no_difference -> { @board_game.game_instructions.count } do
      post api_v1_board_game_instructions_url(@board_game),
        params: { document: upload, language: "en", category: "manual" }
    end

    assert_response :conflict
  end

  test "destroy removes an instruction" do
    instruction = create_instruction!

    assert_difference -> { @board_game.game_instructions.count }, -1 do
      delete api_v1_board_game_instruction_url(@board_game, instruction)
    end

    assert_response :no_content
  end

  test "destroy returns 404 for an unknown instruction" do
    delete api_v1_board_game_instruction_url(@board_game, 0)
    assert_response :not_found
  end
end
