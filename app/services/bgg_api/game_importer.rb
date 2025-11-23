# frozen_string_literal: true

module BggApi
  # Service for importing board games and extensions from BGG API into the database
  class GameImporter
    class ImportError < StandardError; end

    def initialize(client: BggApi::Client.new)
      @client = client
    end

    # Search BGG and import all games from the first 20 results that meet the criteria
    #
    # @param query [String] search query
    # @param options [Hash] optional parameters
    # @option options [Integer] :min_user_ratings minimum user ratings required (default: 10000)
    # @option options [Boolean] :dry_run if true, returns unsaved records without persisting (default: false)
    #
    # @return [Array<BoardGame, Extension>] imported games/extensions (persisted unless dry_run is true)
    #
    # @example
    #   importer = BggApi::GameImporter.new
    #   games = importer.import_from_search("Catan")
    #   # => [#<BoardGame id: 1, name: "Catan">, ...]
    #
    #   # Preview what would be imported without saving
    #   games = importer.import_from_search("Catan", dry_run: true)
    #   # => [#<BoardGame id: nil, name: "Catan">, ...]
    def import_from_search(query, options = {})
      min_ratings = options[:min_user_ratings] || 10_000
      dry_run = options[:dry_run] || false

      # Search BGG
      search_results = @client.search(query)
      return [] if search_results[:items].empty?

      # Get IDs for the first batch (max 20)
      bgg_ids = search_results[:items].first(20).map { |item| item[:id].to_i }
      return [] if bgg_ids.empty?

      Rails.logger.info("Importing #{bgg_ids.length} games from BGG search for query #{query}")

      # Fetch details with filtering - this will filter by min_ratings
      details = @client.get_details(bgg_ids, { min_user_ratings: min_ratings })

      Rails.logger.info("Imported #{details.length} games from BGG search for query #{query}")
      return [] if details.empty?

      # Import all filtered games
      imported = []
      details.each do |game_data|
        imported << import_game(game_data, dry_run: dry_run)
      end

      imported.compact
    rescue BggApi::Client::Error => e
      raise ImportError, "Failed to import games from BGG: #{e.message}"
    end

    # Import a single game from BGG by its ID
    #
    # @param bgg_id [Integer] BGG game ID
    # @param options [Hash] optional parameters
    # @option options [Boolean] :dry_run if true, returns an unsaved record without persisting (default: false)
    #
    # @return [BoardGame, Extension, nil] imported game/extension or nil if not found
    def import_by_id(bgg_id, options = {})
      dry_run = options[:dry_run] || false

      details = @client.get_details([bgg_id], { min_user_ratings: 0 })
      return nil if details.empty?

      import_game(details.first, dry_run: dry_run)
    rescue BggApi::Client::Error => e
      raise ImportError, "Failed to import game #{bgg_id} from BGG: #{e.message}"
    end

    private

    def import_game(game_data, dry_run: false)
      return perform_import(game_data, dry_run: dry_run) if dry_run

      ActiveRecord::Base.transaction do
        perform_import(game_data, dry_run: dry_run)
      end
    end

    def perform_import(game_data, dry_run:)
      case game_data[:type]
      when "boardgame"
        import_board_game(game_data, dry_run: dry_run)
      when "boardgameexpansion"
        import_extension(game_data, dry_run: dry_run)
      else
        raise ImportError, "Unknown game type: #{game_data[:type]}"
      end
    end

    def import_board_game(game_data, dry_run:)
      # Check if already imported
      existing = BggBoardGameAssociation.find_by(bgg_id: game_data[:id])
      return existing.board_game if existing && !dry_run

      board_game = BoardGame.new(
        name: game_data[:name],
        year_published: game_data[:year_published],
        min_players: game_data[:min_players],
        max_players: game_data[:max_players],
        min_playing_time: game_data[:min_playing_time],
        max_playing_time: game_data[:max_playing_time],
        rating: game_data[:rating],
        difficulty_score: game_data[:complexity]
      )

      # Assign game types and categories
      board_game.game_types = find_or_create_game_types(game_data[:mechanics], dry_run: dry_run)
      board_game.game_categories = find_or_create_game_categories(game_data[:categories], dry_run: dry_run)

      return board_game if dry_run

      board_game.save!

      # Create BGG association
      board_game.create_bgg_board_game_association!(bgg_id: game_data[:id])

      board_game
    end

    def import_extension(game_data, dry_run:)
      # Check if already imported
      existing = BggExtensionAssociation.find_by(bgg_id: game_data[:id])
      return existing.extension if existing && !dry_run

      # Extensions need at least one parent game
      parent_game_ids = game_data[:parent_game_ids]
      if parent_game_ids.blank?
        raise ImportError, "Extension #{game_data[:id]} has no parent games"
      end

      # Find the first parent game that exists in our database
      # If multiple parents exist, we'll link to the first one we find
      parent_board_game = find_parent_board_game(parent_game_ids)

      if parent_board_game.nil?
        # Skip this extension for now - parent game not imported yet
        Rails.logger.info("Skipping extension #{game_data[:id]} - parent games #{parent_game_ids.join(', ')} not found")
        return nil
      end

      extension = Extension.new(
        name: game_data[:name],
        year_published: game_data[:year_published],
        board_game: parent_board_game,
        min_players: game_data[:min_players],
        max_players: game_data[:max_players],
        min_playing_time: game_data[:min_playing_time],
        max_playing_time: game_data[:max_playing_time],
        rating: game_data[:rating],
        difficulty_score: game_data[:complexity]
      )

      return extension if dry_run

      extension.save!

      # Create BGG association
      extension.create_bgg_extension_association!(bgg_id: game_data[:id])

      extension
    end

    def find_parent_board_game(parent_game_ids)
      # Look for any of the parent games by their BGG IDs
      parent_game_ids.each do |parent_bgg_id|
        association = BggBoardGameAssociation.find_by(bgg_id: parent_bgg_id)
        return association.board_game if association
      end
      nil
    end

    def find_or_create_game_types(mechanics, dry_run:)
      return [find_or_create_default_game_type(dry_run: dry_run)] if mechanics.blank?

      mechanics.map do |mechanic|
        dry_run ? GameType.new(name: mechanic) : GameType.find_or_create_by!(name: mechanic)
      end
    end

    def find_or_create_game_categories(categories, dry_run:)
      return [find_or_create_default_game_category(dry_run: dry_run)] if categories.blank?

      categories.map do |category|
        dry_run ? GameCategory.new(name: category) : GameCategory.find_or_create_by!(name: category)
      end
    end

    def find_or_create_default_game_type(dry_run:)
      dry_run ? GameType.new(name: "General") : GameType.find_or_create_by!(name: "General")
    end

    def find_or_create_default_game_category(dry_run:)
      dry_run ? GameCategory.new(name: "General") : GameCategory.find_or_create_by!(name: "General")
    end
  end
end