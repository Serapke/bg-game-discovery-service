# frozen_string_literal: true

# Job for importing or updating board games from BoardGameGeek API
#
# This job fetches game data from BGG and imports/updates it in the local database.
# It can handle both new imports and updates to existing games.
# BGG IDs are batched into groups of 20 for efficient API usage.
#
# @example Import/update multiple games
#   BggGameImportJob.perform_later([123456, 789012, 345678])
class BggGameImportJob < ApplicationJob
  queue_as :default

  # BGG API supports fetching up to 20 games at once
  BATCH_SIZE = 20

  # Retry on BGG API errors with exponential backoff
  retry_on BggApi::Client::TimeoutError, wait: :exponentially_longer, attempts: 3
  retry_on BggApi::Client::ApiError, wait: :exponentially_longer, attempts: 3

  # Don't retry on import errors (likely data validation issues)
  discard_on BggApi::GameImporter::ImportError

  # Import or update games from BGG by their IDs
  # Always updates existing games with fresh data from BGG
  #
  # @param bgg_ids [Array<Integer>] Single BGG ID or array of BGG IDs to import
  # @return [Hash] Results with detailed information about each game
  def perform(bgg_ids)
    bgg_ids = Array(bgg_ids).map(&:to_i).uniq

    if bgg_ids.empty?
      Rails.logger.warn("BggGameImportJob called with empty ID list")
      return { imported: [], updated: [], skipped: [], failed: [] }
    end

    Rails.logger.info("Starting BGG import job for #{bgg_ids.length} game(s): #{bgg_ids.join(', ')}")

    importer = BggApi::GameImporter.new

    # Process in batches of 20 (BGG API limit)
    batch_results = bgg_ids.each_slice(BATCH_SIZE).map do |batch|
      Rails.logger.info("Processing batch of #{batch.length} game(s): #{batch.join(', ')}")
      importer.import_by_ids(batch, force_update: true)
    end

    # Combine results from all batches
    results = batch_results.reduce({ imported: [], updated: [], skipped: [], failed: [] }) do |combined, batch_result|
      {
        imported: combined[:imported] + batch_result[:imported],
        updated: combined[:updated] + batch_result[:updated],
        skipped: combined[:skipped] + batch_result[:skipped],
        failed: combined[:failed] + batch_result[:failed]
      }
    end

    log_summary(results)

    results
  end

  private

  def log_summary(results)
    total = results[:imported].length + results[:updated].length + results[:skipped].length + results[:failed].length

    Rails.logger.info("=" * 80)
    Rails.logger.info("BGG Import Job Summary")
    Rails.logger.info("=" * 80)
    Rails.logger.info("Total games processed: #{total}")
    Rails.logger.info("  - Imported: #{results[:imported].length}")
    Rails.logger.info("  - Updated: #{results[:updated].length}")
    Rails.logger.info("  - Skipped: #{results[:skipped].length}")
    Rails.logger.info("  - Failed: #{results[:failed].length}")

    if results[:imported].any?
      Rails.logger.info("\nImported games:")
      results[:imported].each do |game|
        Rails.logger.info("  - #{game[:bgg_id]}: #{game[:name]} (#{game[:year_published]})")
      end
    end

    if results[:updated].any?
      Rails.logger.info("\nUpdated games:")
      results[:updated].each do |game|
        Rails.logger.info("  - #{game[:bgg_id]}: #{game[:name]} (#{game[:year_published]})")
      end
    end

    if results[:skipped].any?
      Rails.logger.info("\nSkipped games:")
      results[:skipped].each do |game|
        Rails.logger.info("  - #{game[:bgg_id]}: #{game[:name]} (#{game[:reason]})")
      end
    end

    if results[:failed].any?
      Rails.logger.info("\nFailed games:")
      results[:failed].each do |game|
        Rails.logger.info("  - #{game[:bgg_id]}: #{game[:error]}")
      end
    end

    Rails.logger.info("=" * 80)
  end
end
