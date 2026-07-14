# frozen_string_literal: true

require "test_helper"

class VideoTest < ActiveSupport::TestCase
  test "belongs to a board game" do
    association = Video.reflect_on_association(:board_game)
    assert_equal :belongs_to, association.macro
  end
end
