class CreateBoardGameRelations < ActiveRecord::Migration[8.0]
  def change
    create_table :board_game_relations do |t|
      t.bigint :source_game_id, null: false
      t.bigint :target_game_id, null: false
      t.string :relation_type, null: false, limit: 50

      t.timestamps

      # Foreign keys
      t.foreign_key :board_games, column: :source_game_id, on_delete: :cascade
      t.foreign_key :board_games, column: :target_game_id, on_delete: :cascade

      # Indexes
      t.index [:source_game_id, :target_game_id, :relation_type],
              unique: true,
              name: 'idx_bg_relations_unique'
      t.index [:target_game_id, :source_game_id, :relation_type],
              name: 'idx_bg_relations_reverse'

      # Check constraint: prevent self-relations
      t.check_constraint 'source_game_id != target_game_id',
                         name: 'prevent_self_relation'
    end
  end
end
