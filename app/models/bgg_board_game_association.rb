class BggBoardGameAssociation < ApplicationRecord
  belongs_to :board_game

  validates :bgg_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :bgg_id, uniqueness: true
  validates :board_game_id, uniqueness: { scope: :bgg_id }
end