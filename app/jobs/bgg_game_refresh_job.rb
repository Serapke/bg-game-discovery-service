# frozen_string_literal: true

# Refreshes a single board game (and one level of its recommended games) from BGG.
#
# Differs from BggGameImportJob in three ways:
# - Force-updates the seed game's fields (depth 0).
# - Recursively enqueues itself for recommended games that aren't in the local DB yet (depth 1).
# - Carries an explicit BGG-call budget so a single refresh click can't fan out unboundedly.
#
# At depth >= 1 it skips fetching recommendations of the recommended games — those just
# need to exist locally so the seed game's recommendation event can resolve them.
class BggGameRefreshJob < ApplicationJob
  queue_as :default

  MAX_DEPTH = 1
  MAX_BGG_CALLS = 10
  BATCH_SIZE = 20

  retry_on BggApi::Client::TimeoutError, wait: :exponentially_longer, attempts: 3
  retry_on BggApi::Client::ApiError, wait: :exponentially_longer, attempts: 3
  discard_on BggApi::GameImporter::ImportError

  def perform(bgg_ids, depth: 0, remaining_calls: MAX_BGG_CALLS)
    bgg_ids = Array(bgg_ids).map(&:to_i).uniq
    return if bgg_ids.empty? || remaining_calls <= 0

    # import_by_ids makes 1 get_details call per batch plus 1 get_recommendations call
    # per imported/updated game (skipped at depth >= 1).
    calls_this_step = 1 + (depth.zero? ? bgg_ids.length : 0)
    return if calls_this_step > remaining_calls

    Rails.logger.info("BggGameRefreshJob depth=#{depth} ids=#{bgg_ids.join(',')} budget=#{remaining_calls}")

    importer = BggApi::GameImporter.new
    result = importer.import_by_ids(bgg_ids,
                                    force_update: depth.zero?,
                                    skip_recommendations: depth.positive?)
    remaining = remaining_calls - calls_this_step

    return if depth >= MAX_DEPTH || remaining <= 0

    next_ids = result[:related_ids].first(BATCH_SIZE)
    if next_ids.any?
      BggGameRefreshJob.perform_later(next_ids, depth: depth + 1, remaining_calls: remaining)
      # After the recursive import lands, re-publish the seed's recommendations so the
      # recommender-service picks up the newly-imported recommended games.
      bgg_ids.each do |seed_bgg_id|
        BggRepublishRecommendationsJob.set(wait: 30.seconds).perform_later(seed_bgg_id)
      end
    end
  end
end
