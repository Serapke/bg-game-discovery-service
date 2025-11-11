class CreateBggBoardGameAssociations < ActiveRecord::Migration[8.0]
  def change
    create_table :bgg_board_game_associations do |t|
      t.references :board_game, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.bigint :bgg_id, null: false, index: { unique: true }
      t.string :bgg_type, null: false, limit: 50

      t.timestamps null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end

    # Add a unique index to prevent duplicate associations
    add_index :bgg_board_game_associations, [:board_game_id, :bgg_id], unique: true, name: 'index_bgg_associations_on_board_game_and_bgg_id'

    # Add a check constraint to ensure bgg_id is positive
    execute <<-SQL
      ALTER TABLE bgg_board_game_associations
        ADD CONSTRAINT check_bgg_id_positive
        CHECK (bgg_id > 0);
    SQL
  end
end
