require "test_helper"

class BggExtensionAssociationTest < ActiveSupport::TestCase
  def setup
    @board_game = board_games(:catan)
    @extension = Extension.create!(
      name: "Test Extension",
      year_published: 2021,
      board_game: @board_game,
      min_players: 3,
      max_players: 5
    )
    @bgg_extension_association = BggExtensionAssociation.new(
      extension: @extension,
      bgg_id: 67890
    )
  end

  test "should be valid with valid attributes" do
    assert @bgg_extension_association.valid?
  end

  test "should require extension" do
    @bgg_extension_association.extension = nil
    assert_not @bgg_extension_association.valid?
    assert_includes @bgg_extension_association.errors[:extension], "must exist"
  end

  test "should require bgg_id" do
    @bgg_extension_association.bgg_id = nil
    assert_not @bgg_extension_association.valid?
    assert_includes @bgg_extension_association.errors[:bgg_id], "can't be blank"
  end

  test "bgg_id should be a positive integer" do
    @bgg_extension_association.bgg_id = 0
    assert_not @bgg_extension_association.valid?
    assert_includes @bgg_extension_association.errors[:bgg_id], "must be greater than 0"

    @bgg_extension_association.bgg_id = -1
    assert_not @bgg_extension_association.valid?
    assert_includes @bgg_extension_association.errors[:bgg_id], "must be greater than 0"
  end

  test "bgg_id should be unique" do
    @bgg_extension_association.save!

    another_extension = Extension.create!(
      name: "Another Extension",
      year_published: 2022,
      board_game: @board_game,
      min_players: 2,
      max_players: 4
    )

    duplicate = BggExtensionAssociation.new(
      extension: another_extension,
      bgg_id: 67890
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:bgg_id], "has already been taken"
  end

  test "should allow same extension with different bgg_id" do
    @bgg_extension_association.save!

    another_association = BggExtensionAssociation.new(
      extension: @extension,
      bgg_id: 99999
    )

    assert another_association.valid?
  end

  test "should belong to extension" do
    @bgg_extension_association.save!

    assert_equal @extension, @bgg_extension_association.extension
    assert_equal @bgg_extension_association, @extension.bgg_extension_association
  end

  test "should be destroyed when extension is destroyed" do
    @bgg_extension_association.save!

    assert_difference 'BggExtensionAssociation.count', -1 do
      @extension.destroy
    end
  end
end
