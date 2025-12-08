# frozen_string_literal: true

module BggApi
  # Service for searching BGG and importing all matching games
  # Imports the first batch immediately and enqueues the rest as background jobs
  class SearchImporter
    class ImportError < StandardError; end

    def initialize(client: BggApi::Client.new)
      @client = client
    end

    # Search BGG and import all games from the results
    # First 20 games are imported immediately (synchronous)
    # Remaining games are enqueued for background import
    #
    # @param query [String] search query
    #
    # @return [Hash] Summary of the import operation
    #   {
    #     total_found: 45,
    #     imported_immediately: [<BoardGame>, ...],
    #     enqueued_count: 25,
    #     enqueued_ids: [123, 456, ...]
    #   }
    def import_from_search(query)

      # Search BGG
      search_results = @client.search(query)

      if search_results[:items].empty?
        Rails.logger.info("No games found for search query: #{query}")
        return {
          total_found: 0,
          imported_immediately: [],
          enqueued_count: 0,
          enqueued_ids: []
        }
      end

      # Get all IDs from search results
      all_ids = search_results[:items].map { |item| item[:id].to_i }

      Rails.logger.info("Found #{all_ids.length} games from BGG search for query '#{query}'")

      # Split into immediate and background batches
      immediate_ids = all_ids.first(20)
      remaining_ids = all_ids.drop(20)

      # Import the first batch immediately
      Rails.logger.info("Importing first #{immediate_ids.length} games immediately")
      importer = BggApi::GameImporter.new(client: @client)

      result = importer.import_by_ids(immediate_ids, force_update: false)
      imported_games = result[:imported].map { |r| BoardGame.find(r[:board_game_id]) }

      Rails.logger.info("Imported #{imported_games.length} games immediately")

      # Collect all IDs for background import: remaining search results + related games
      background_ids = (remaining_ids + result[:related_ids]).uniq

      # Enqueue for background import
      if background_ids.any?
        Rails.logger.info("Enqueueing #{background_ids.length} games for background import (#{remaining_ids.length} from search + #{result[:related_ids].length} related)")
        BggGameImportJob.perform_later(background_ids)
      end

      {
        total_found: all_ids.length,
        imported_immediately: imported_games,
        enqueued_count: background_ids.length,
        enqueued_ids: background_ids
      }
    rescue BggApi::Client::Error => e
      raise ImportError, "Failed to import games from BGG search: #{e.message}"
    end
  end
end
