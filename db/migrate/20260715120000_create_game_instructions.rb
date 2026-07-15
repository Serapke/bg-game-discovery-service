class CreateGameInstructions < ActiveRecord::Migration[8.0]
  def change
    create_table :game_instructions do |t|
      t.references :board_game, null: false, foreign_key: true
      t.string :language, null: false
      t.string :category, null: false

      t.timestamps
    end

    # One instruction file per game + language + category (e.g. a single
    # "English manual"); a second upload for the same combo is rejected.
    add_index :game_instructions,
              [:board_game_id, :language, :category],
              unique: true,
              name: "index_game_instructions_on_game_language_category"
  end
end
