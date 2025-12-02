class DropExtensionsTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :bgg_extension_associations
    drop_table :extensions
  end

  def down
    # Recreate extensions table
    create_table :extensions, id: :serial do |t|
      t.string :name, limit: 255, null: false
      t.integer :board_game_id, null: false
      t.integer :min_players
      t.integer :max_players
      t.integer :min_playing_time
      t.integer :max_playing_time
      t.decimal :rating, precision: 3, scale: 2
      t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamptz :updated_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.decimal :difficulty_score, precision: 3, scale: 2
      t.integer :year_published, null: false
      t.integer :rating_count

      t.index :board_game_id
      t.index :name

      t.check_constraint 'max_players >= min_players'
      t.check_constraint 'max_playing_time >= min_playing_time'
      t.check_constraint 'min_players > 0'
      t.check_constraint 'min_playing_time > 0'
      t.check_constraint 'rating >= 0 AND rating <= 10'
      t.check_constraint 'rating_count >= 0'
    end

    add_foreign_key :extensions, :board_games, on_delete: :cascade

    # Recreate bgg_extension_associations table
    create_table :bgg_extension_associations do |t|
      t.bigint :extension_id, null: false
      t.bigint :bgg_id, null: false
      t.datetime :created_at, default: -> { 'CURRENT_TIMESTAMP' }, null: false
      t.datetime :updated_at, default: -> { 'CURRENT_TIMESTAMP' }, null: false

      t.index :bgg_id, unique: true
      t.index [:extension_id, :bgg_id], unique: true, name: 'index_bgg_ext_associations_on_extension_and_bgg_id'
      t.index :extension_id

      t.check_constraint 'bgg_id > 0', name: 'check_bgg_ext_id_positive'
    end

    add_foreign_key :bgg_extension_associations, :extensions, on_delete: :cascade
  end
end
