class AddGameTypeToBoardGames < ActiveRecord::Migration[8.0]
  def change
    add_column :board_games, :game_type, :string

    reversible do |dir|
      dir.up do
        # Set a default value for existing records
        execute "UPDATE board_games SET game_type = 'family' WHERE game_type IS NULL"

        # Now add the NOT NULL constraint
        change_column_null :board_games, :game_type, false
      end
    end
  end
end
