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
    # @option options [Integer] :min_user_ratings minimum user ratings required (default: 1000)
    # @option options [Boolean] :dry_run if true, returns unsaved records without persisting (default: false)
    #
    # @return [Array<BoardGame>] imported games/expansions (persisted unless dry_run is true)
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
      min_ratings = options[:min_user_ratings] || 1_000
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
    # @return [BoardGame, nil] imported game/expansion or nil if not found
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
      thing_type = game_data[:thing_type]

      # Validate thing_type
      unless %w[boardgame boardgameexpansion].include?(thing_type)
        raise ImportError, "Unknown game type: #{thing_type}"
      end

      is_expansion = thing_type == "boardgameexpansion"

      # Import as a board game regardless of type
      board_game = import_board_game(game_data, dry_run: dry_run)
      return board_game unless board_game && is_expansion && !dry_run

      # If it's an expansion, create the 'expands' relationship(s)
      parent_game_ids = game_data[:parent_game_ids]
      if parent_game_ids.present?
        found_parents, not_found_ids = find_parent_board_games(parent_game_ids)

        # Create relations for all found parent games (skip if already exists)
        found_parents.each do |parent_board_game|
          BoardGameRelation.find_or_create_by!(
            source_game: board_game,
            target_game: parent_board_game,
            relation_type: :expands
          )
        end

        # Log any parent games that weren't found
        if not_found_ids.any?
          Rails.logger.info("Expansion #{game_data[:id]} imported but parent games #{not_found_ids.join(', ')} not found in database")
        end
      end

      board_game
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
        rating_count: game_data[:user_ratings_count],
        difficulty_score: game_data[:complexity]
      )

      # Assign game categories
      board_game.game_categories = find_or_create_game_categories(game_data[:categories], dry_run: dry_run)

      # Assign game types with ranks
      assign_game_types_with_ranks(board_game, game_data[:types], dry_run: dry_run)

      return board_game if dry_run

      board_game.save!

      # Create BGG association
      board_game.create_bgg_board_game_association!(bgg_id: game_data[:id])

      board_game
    end

    def find_parent_board_games(parent_game_ids)
      # Fetch all parent games in a single query
      associations = BggBoardGameAssociation.where(bgg_id: parent_game_ids).includes(:board_game)

      found_parents = associations.map(&:board_game)
      found_bgg_ids = associations.map(&:bgg_id)
      not_found_ids = parent_game_ids - found_bgg_ids

      [found_parents, not_found_ids]
    end

    def assign_game_types_with_ranks(board_game, types_data, dry_run:)
      # types_data is now an array of hashes: [{name: "strategy", rank: 123}, ...]
      if types_data.blank?
        default_type = dry_run ? GameType.new(name: "General") : GameType.find_or_create_by!(name: "General")
        board_game.game_types = [default_type]
        return
      end

      if dry_run
        # For dry_run, just assign unsaved GameType instances
        board_game.game_types = types_data.map { |type_info| GameType.new(name: type_info[:name]) }
      else
        # Find or create all game types and build join records with ranks
        game_types_with_ranks = types_data.map do |type_info|
          game_type = GameType.find_or_create_by!(name: type_info[:name])
          { game_type: game_type, rank: type_info[:rank] }
        end

        # Assign game types to satisfy validation
        board_game.game_types = game_types_with_ranks.map { |gt| gt[:game_type] }

        # Then update the join records with rank values
        game_types_with_ranks.each do |gt_info|
          join_record = board_game.board_game_game_types.find { |bgt| bgt.game_type_id == gt_info[:game_type].id }
          join_record.rank = gt_info[:rank] if join_record
        end
      end
    end

    def find_or_create_game_types(types, dry_run:)
      return [find_or_create_default_game_type(dry_run: dry_run)] if types.blank?

      types.map do |type|
        dry_run ? GameType.new(name: type) : GameType.find_or_create_by!(name: type)
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