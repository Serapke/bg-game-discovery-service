class AddImageUrlsToBoardGames < ActiveRecord::Migration[7.0]
  def change
    add_column :board_games, :image_url, :string
    add_column :board_games, :thumbnail_url, :string
  end
end
