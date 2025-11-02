class AddDifficultyScoreToExtensions < ActiveRecord::Migration[8.0]
  def change
    add_column :extensions, :difficulty_score, :decimal, precision: 3, scale: 2
  end
end
