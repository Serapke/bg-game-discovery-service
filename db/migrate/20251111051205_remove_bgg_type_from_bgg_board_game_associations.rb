class RemoveBggTypeFromBggBoardGameAssociations < ActiveRecord::Migration[8.0]
  def change
    remove_column :bgg_board_game_associations, :bgg_type, :string
  end
end
