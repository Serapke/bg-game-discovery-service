class AddYearPublishedToBoardGamesAndExtensions < ActiveRecord::Migration[8.0]
  def change
    add_column :board_games, :year_published, :integer, null: false
    add_column :extensions, :year_published, :integer, null: false
  end
end
