require "test_helper"
require "minitest/mock"

class GameInstructionTest < ActiveSupport::TestCase
  def setup
    @board_game = board_games(:catan)
  end

  def build_instruction(filename: "sample.pdf", content_type: "application/pdf",
                        language: "en", category: "manual")
    instruction = @board_game.game_instructions.new(language: language, category: category)
    instruction.document.attach(
      io: file_fixture(filename).open,
      filename: filename,
      content_type: content_type
    )
    instruction
  end

  test "is valid with an attached PDF, language, and category" do
    assert build_instruction.valid?
  end

  test "is invalid without an attached document" do
    instruction = @board_game.game_instructions.new(language: "en", category: "manual")
    assert_not instruction.valid?
    assert_includes instruction.errors[:document], "must be provided"
  end

  test "rejects an unknown language" do
    assert_not build_instruction(language: "de").valid?
  end

  test "rejects an unknown category" do
    assert_not build_instruction(category: "cheatsheet").valid?
  end

  test "rejects a non-PDF file" do
    instruction = build_instruction(filename: "sample.txt", content_type: "text/plain")
    assert_not instruction.valid?
    assert_includes instruction.errors[:document], "must be a PDF"
  end

  test "rejects a non-PDF even when declared as a PDF" do
    # Text bytes lying about being a PDF must still be caught by the byte sniff.
    instruction = build_instruction(filename: "sample.txt", content_type: "application/pdf")
    assert_not instruction.valid?
    assert_includes instruction.errors[:document], "must be a PDF"
  end

  test "accepts a valid PDF declared with a generic content type" do
    instruction = build_instruction(content_type: "application/octet-stream")
    assert instruction.valid?, instruction.errors.full_messages.to_sentence
  end

  test "normalizes the blob content type to the sniffed value" do
    instruction = build_instruction(content_type: "application/octet-stream")
    instruction.save!
    assert_equal "application/pdf", instruction.document.blob.content_type
  end

  test "rejects an empty file with a clear message" do
    instruction = @board_game.game_instructions.new(language: "en", category: "manual")
    instruction.document.attach(
      io: StringIO.new(""), filename: "empty.pdf", content_type: "application/pdf"
    )
    assert_not instruction.valid?
    assert instruction.errors[:document].any? { |m| m.include?("empty") }
  end

  test "rejects a document larger than the size cap" do
    instruction = build_instruction
    instruction.document.blob.stub(:byte_size, GameInstruction::MAX_FILE_SIZE + 1) do
      assert_not instruction.valid?
      assert instruction.errors[:document].any? { |m| m.include?("smaller than") }
    end
  end

  test "rejects a duplicate game + language + category" do
    build_instruction(language: "en", category: "manual").save!
    duplicate = build_instruction(language: "en", category: "manual")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:category, :taken)
  end

  test "allows the same category in a different language" do
    build_instruction(language: "en", category: "manual").save!
    assert build_instruction(language: "lt", category: "manual").valid?
  end

  test "allows a different category in the same language" do
    build_instruction(language: "en", category: "manual").save!
    assert build_instruction(language: "en", category: "guide").valid?
  end
end
