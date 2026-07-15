require "test_helper"

class Api::V1::GamePhotosControllerTest < ActionDispatch::IntegrationTest
  def setup
    @board_game = board_games(:catan)
  end

  def upload(filename: "sample.png", content_type: "image/png")
    fixture_file_upload(filename, content_type)
  end

  def create_photo!
    @board_game.game_photos.create! do |p|
      p.image.attach(io: file_fixture("sample.png").open, filename: "sample.png", content_type: "image/png")
    end
  end

  test "index lists a game's photos" do
    photo = create_photo!
    get api_v1_board_game_photos_url(@board_game)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    assert_equal photo.id, body.first["id"]
    assert body.first["url"].present?
    assert body.first["thumbnail_url"].present?
  end

  test "index returns 404 for an unknown game" do
    get api_v1_board_game_photos_url(board_game_id: 0)
    assert_response :not_found
  end

  test "create uploads a photo" do
    assert_difference -> { @board_game.game_photos.count }, 1 do
      post api_v1_board_game_photos_url(@board_game), params: { image: upload }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["id"].present?
    assert body["url"].present?
  end

  test "create rejects a non-image file" do
    assert_no_difference -> { @board_game.game_photos.count } do
      post api_v1_board_game_photos_url(@board_game),
        params: { image: upload(filename: "sample.txt", content_type: "text/plain") }
    end

    assert_response :unprocessable_entity
  end

  test "create without an image returns bad request" do
    post api_v1_board_game_photos_url(@board_game)
    assert_response :bad_request
  end

  test "destroy removes a photo" do
    photo = create_photo!

    assert_difference -> { @board_game.game_photos.count }, -1 do
      delete api_v1_board_game_photo_url(@board_game, photo)
    end

    assert_response :no_content
  end

  test "destroy returns 404 for an unknown photo" do
    delete api_v1_board_game_photo_url(@board_game, 0)
    assert_response :not_found
  end
end
