class Extension < ApplicationRecord
  belongs_to :board_game

  validates :name, presence: true
  validates :min_players, numericality: { greater_than: 0 }, allow_nil: true
  validates :max_players, numericality: { greater_than_or_equal_to: :min_players }, allow_nil: true
  validates :min_playing_time, numericality: { greater_than: 0 }, allow_nil: true
  validates :max_playing_time, numericality: { greater_than_or_equal_to: :min_playing_time }, allow_nil: true
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true
end