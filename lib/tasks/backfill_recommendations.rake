namespace :backfill do
  desc "Fetch and publish recommendations for all existing board games via BGG"
  task recommendations: :environment do
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
