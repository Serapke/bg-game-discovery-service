namespace :backfill do
  desc "Re-import all existing board games from BGG to populate image_url and thumbnail_url"
  task game_images: :environment do
    bgg_ids = BggBoardGameAssociation.pluck(:bgg_id)

    if bgg_ids.empty?
      puts "No games to backfill."
      next
    end

    puts "Enqueuing BggGameImportJob for #{bgg_ids.length} game(s) in batches of 20..."

    bgg_ids.each_slice(BggGameImportJob::BATCH_SIZE).with_index do |batch, i|
      BggGameImportJob.perform_later(batch)
      puts "  Batch #{i + 1}: #{batch.length} game(s) enqueued"
    end

    puts "Done. Watch Solid Queue to track progress."
  end
end
