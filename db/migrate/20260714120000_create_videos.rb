class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.bigint :board_game_id, null: false
      t.string :youtube_video_id, null: false
      t.string :link, null: false
      t.string :title
      t.string :category
      t.string :language

      t.timestamps

      t.foreign_key :board_games, column: :board_game_id, on_delete: :cascade

      t.index [:board_game_id, :youtube_video_id],
              unique: true,
              name: 'idx_videos_unique_per_game'
    end
  end
end
