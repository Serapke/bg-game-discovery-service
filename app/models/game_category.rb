class GameCategory < ApplicationRecord
  has_and_belongs_to_many :board_games

  validates :name, presence: true, uniqueness: true
end
