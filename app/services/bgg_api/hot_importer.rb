# frozen_string_literal: true

module BggApi
  # Service for fetching the BGG "hot" list and importing all games on it.
  # First 20 are imported immediately; the rest (plus related games surfaced
  # during import) are enqueued for background import.
  class HotImporter
    class ImportError < StandardError; end

    def initialize(client: BggApi::Client.new)
      @client = client
    end

    # @return [Hash] {
    #   total_found: Integer,
    #   all_ids: Array<Integer>,            # BGG IDs in hot-rank order
    #   imported_immediately: Array<BoardGame>,
    #   enqueued_ids: Array<Integer>
    # }
    def import_hot
      hot_results = @client.hot

      if hot_results[:items].empty?
        Rails.logger.info("BGG hot list returned no items")
        return { total_found: 0, all_ids: [], imported_immediately: [], enqueued_ids: [] }
      end

      all_ids = hot_results[:items].map { |item| item[:id].to_i }
      Rails.logger.info("Fetched #{all_ids.length} games from BGG hot list")

      immediate_ids = all_ids.first(20)
      remaining_ids = all_ids.drop(20)

      importer = BggApi::GameImporter.new(client: @client)
      result = importer.import_by_ids(immediate_ids, force_update: false)
      imported_games = result[:imported].map { |r| BoardGame.find(r[:board_game_id]) }

      background_ids = (remaining_ids + result[:related_ids]).uniq
      if background_ids.any?
        Rails.logger.info("Enqueueing #{background_ids.length} hot-list games for background import")
        BggGameImportJob.perform_later(background_ids)
      end

      {
        total_found: all_ids.length,
        all_ids: all_ids,
        imported_immediately: imported_games,
        enqueued_ids: background_ids
      }
    rescue BggApi::Client::Error => e
      raise ImportError, "Failed to import games from BGG hot list: #{e.message}"
    end
  end
end
