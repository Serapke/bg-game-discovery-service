class CreateGameCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :game_categories do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :game_categories, :name, unique: true
  end
end
