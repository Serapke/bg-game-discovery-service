require "test_helper"
require "minitest/mock"

class GamePhotoTest < ActiveSupport::TestCase
  def setup
    @board_game = board_games(:catan)
  end

  def build_photo(filename: "sample.png", content_type: "image/png")
    photo = @board_game.game_photos.new
    photo.image.attach(
      io: file_fixture(filename).open,
      filename: filename,
      content_type: content_type
    )
    photo
  end

  test "is valid with an attached image" do
    assert build_photo.valid?
  end

  test "is invalid without an attached image" do
    photo = @board_game.game_photos.new
    assert_not photo.valid?
    assert_includes photo.errors[:image], "must be provided"
  end

  test "accepts jpeg, png, and avif" do
    assert build_photo(filename: "sample.jpg", content_type: "image/jpeg").valid?
    assert build_photo(filename: "sample.png", content_type: "image/png").valid?
    assert build_photo(filename: "sample.avif", content_type: "image/jpeg").valid?
  end

  test "detects avif from bytes even when declared as jpeg" do
    photo = build_photo(filename: "sample.avif", content_type: "image/jpeg")
    photo.save!
    assert_equal "image/avif", photo.image.blob.content_type
  end

  test "rejects an empty file with a clear message" do
    photo = @board_game.game_photos.new
    photo.image.attach(
      io: StringIO.new(""), filename: "empty.jpg", content_type: "image/jpeg"
    )
    assert_not photo.valid?
    assert photo.errors[:image].any? { |m| m.include?("empty") }
    assert_empty photo.errors[:image].select { |m| m.include?("JPEG, PNG, WebP") }
  end

  test "rejects a non-image content type" do
    photo = build_photo(filename: "sample.txt", content_type: "text/plain")
    assert_not photo.valid?
    assert_includes photo.errors[:image], "must be a JPEG, PNG, WebP, or AVIF image"
  end

  test "accepts a valid image declared with a generic content type" do
    # Browsers/OSes sometimes send application/octet-stream for a real JPEG.
    photo = build_photo(filename: "sample.jpg", content_type: "application/octet-stream")
    assert photo.valid?, photo.errors.full_messages.to_sentence
  end

  test "normalizes the blob content type to the sniffed value" do
    photo = build_photo(filename: "sample.jpg", content_type: "application/octet-stream")
    photo.save!
    assert_equal "image/jpeg", photo.image.blob.content_type
  end

  test "rejects a non-image even when declared as an image" do
    # Text bytes lying about being a JPEG must still be caught by the byte sniff.
    photo = build_photo(filename: "sample.txt", content_type: "image/jpeg")
    assert_not photo.valid?
    assert_includes photo.errors[:image], "must be a JPEG, PNG, WebP, or AVIF image"
  end

  test "rejects an image larger than the size cap" do
    photo = build_photo
    photo.image.blob.stub(:byte_size, GamePhoto::MAX_FILE_SIZE + 1) do
      assert_not photo.valid?
      assert photo.errors[:image].any? { |m| m.include?("smaller than") }
    end
  end

  test "rejects a photo beyond the per-game cap" do
    GamePhoto::MAX_PER_GAME.times { build_photo.save! }
    photo = build_photo
    assert_not photo.valid?
    assert_includes photo.errors[:base], "a game can have at most #{GamePhoto::MAX_PER_GAME} photos"
  end
end
