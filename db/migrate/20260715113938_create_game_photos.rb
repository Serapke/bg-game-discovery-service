class CreateGamePhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :game_photos do |t|
      t.references :board_game, null: false, foreign_key: true

      t.timestamps
    end
  end
end
