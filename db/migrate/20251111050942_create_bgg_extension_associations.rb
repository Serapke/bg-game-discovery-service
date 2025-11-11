class CreateBggExtensionAssociations < ActiveRecord::Migration[8.0]
  def change
    create_table :bgg_extension_associations do |t|
      t.references :extension, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.bigint :bgg_id, null: false, index: { unique: true }

      t.timestamps null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end

    # Add a unique index to prevent duplicate associations
    add_index :bgg_extension_associations, [:extension_id, :bgg_id], unique: true, name: 'index_bgg_ext_associations_on_extension_and_bgg_id'

    # Add a check constraint to ensure bgg_id is positive
    execute <<-SQL
      ALTER TABLE bgg_extension_associations
        ADD CONSTRAINT check_bgg_ext_id_positive
        CHECK (bgg_id > 0);
    SQL
  end
end
