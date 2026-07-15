class Video < ApplicationRecord
  belongs_to :board_game

  validates :title, presence: true
end
