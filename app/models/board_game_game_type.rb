class BoardGameGameType < ApplicationRecord
  self.table_name = "board_games_game_types"
  self.primary_key = [:board_game_id, :game_type_id]

  belongs_to :board_game
  belongs_to :game_type

  validates :rank, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
