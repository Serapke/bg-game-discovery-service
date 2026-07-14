class AddYoutubeEnrichmentToVideos < ActiveRecord::Migration[8.0]
  def change
    change_table :videos, bulk: true do |t|
      t.integer :duration_seconds
      t.bigint :view_count
      t.bigint :like_count
      t.bigint :comment_count
      t.string :thumbnail_url
      # null until the row has been enriched from the YouTube Data API;
      # link-only rows (fresh import or fail-soft) keep this null.
      t.datetime :enriched_at
    end
  end
end
