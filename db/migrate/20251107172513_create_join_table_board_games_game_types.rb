class CreateJoinTableBoardGamesGameTypes < ActiveRecord::Migration[8.0]
  def change
    create_join_table :board_games, :game_types do |t|
      t.index [:board_game_id, :game_type_id]
      t.index [:game_type_id, :board_game_id]
    end
  end
end
