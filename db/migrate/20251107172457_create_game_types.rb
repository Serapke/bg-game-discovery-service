class CreateGameTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :game_types do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :game_types, :name, unique: true
  end
end
