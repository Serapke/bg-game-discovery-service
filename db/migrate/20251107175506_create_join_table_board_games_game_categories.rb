class CreateJoinTableBoardGamesGameCategories < ActiveRecord::Migration[8.0]
  def change
    create_join_table :board_games, :game_categories do |t|
      t.index [:board_game_id, :game_category_id]
      t.index [:game_category_id, :board_game_id]
    end
  end
end
