# frozen_string_literal: true

module BggApi
  # Service for importing board games and extensions from BGG API into the database
  class GameImporter
    class ImportError < StandardError; end

    def initialize(client: BggApi::Client.new)
      @client = client
    end

    # Import multiple games from BGG by their IDs (max 20 IDs per call)
    #
    # @param bgg_ids [Array<Integer>] Array of BGG game IDs (max 20)
    # @param options [Hash] optional parameters
    # @option options [Boolean] :dry_run if true, returns unsaved records without persisting (default: false)
    # @option options [Boolean] :force_update if true, updates existing games even if already imported (default: false)
    #
    # @return [Hash] Results with detailed information about each game
    #   {
    #     imported: [{ bgg_id:, board_game_id:, name:, ... }],
    #     updated: [{ bgg_id:, board_game_id:, name:, ... }],
    #     skipped: [{ bgg_id:, name:, reason: }],
    #     failed: [{ bgg_id:, error: }],
    #     related_ids: [123, 456, ...]  # BGG IDs of related games that should be imported
    #   }
    #
    # @raise [ArgumentError] if more than 20 IDs are provided
    def import_by_ids(bgg_ids, options = {})
      dry_run = options[:dry_run] || false
      force_update = options[:force_update] || false
      bgg_ids = bgg_ids.uniq

      if bgg_ids.length > 20
        raise ArgumentError, "Cannot import more than 20 games at once (got #{bgg_ids.length})"
      end

      return { imported: [], updated: [], skipped: [], failed: [], related_ids: [] } if bgg_ids.empty?

      Rails.logger.info("Importing #{bgg_ids.length} games from BGG by IDs: #{bgg_ids.join(', ')}")

      imported = []
      updated = []
      skipped = []
      failed = []
      related_ids = Set.new

      begin
        details = @client.get_details(bgg_ids, { min_user_ratings: 1_000 })

        if details.empty?
          Rails.logger.warn("No games found for IDs: #{bgg_ids.join(', ')}")
          return {
            imported: [],
            updated: [],
            skipped: [],
            failed: bgg_ids.map { |id| { bgg_id: id, error: "Not found on BGG" } },
            related_ids: []
          }
        end

        # Import each game and collect related IDs
        details.each do |game_data|
          result = import_game_with_result(game_data, dry_run: dry_run, force_update: force_update)

          # noinspection RubyCaseWithoutElseBlockInspection
          case result[:status]
          when :imported
            imported << result
          when :updated
            updated << result
          when :skipped
            skipped << result
          when :failed
            failed << result
          end

          # Collect all related game IDs from links
          if game_data[:links]
            game_data[:links].each_value do |link_ids|
              related_ids.merge(link_ids) if link_ids.is_a?(Array)
            end
          end
        end

        # Check for missing IDs
        returned_ids = details.map { |d| d[:id] }
        missing_ids = bgg_ids - returned_ids
        if missing_ids.any?
          Rails.logger.warn("Games not found on BGG: #{missing_ids.join(', ')}")
          failed.concat(missing_ids.map { |id| { bgg_id: id, error: "Not found on BGG" } })
        end
      rescue BggApi::Client::Error => e
        Rails.logger.error("BGG API error for IDs #{bgg_ids.join(', ')}: #{e.message}")
        raise ImportError, "Failed to import games from BGG: #{e.message}"
      end

      # Remove already imported games from related_ids
      existing_bgg_ids = BggBoardGameAssociation.where(bgg_id: related_ids.to_a).pluck(:bgg_id)
      related_ids -= existing_bgg_ids

      if related_ids.any?
        Rails.logger.info("Found #{related_ids.length} related games to import: #{related_ids.to_a.join(', ')}")
      end

      { imported: imported, updated: updated, skipped: skipped, failed: failed, related_ids: related_ids.to_a }
    end

    private

    def import_game(game_data, dry_run: false, force_update: false)
      return perform_import(game_data, dry_run: dry_run, force_update: force_update) if dry_run

      ActiveRecord::Base.transaction do
        perform_import(game_data, dry_run: dry_run, force_update: force_update)
      end
    end

    def perform_import(game_data, dry_run:, force_update: false)
      thing_type = game_data[:thing_type]

      # Validate thing_type
      unless %w[boardgame boardgameexpansion].include?(thing_type)
        raise ImportError, "Unknown game type: #{thing_type}"
      end

      # Import as a board game regardless of type
      board_game = import_board_game(game_data, dry_run: dry_run, force_update: force_update)
      return board_game unless board_game && !dry_run

      # Create game relationships from BGG links
      links = game_data[:links] || {}
      links.each do |relation_type, target_game_ids|
        next if target_game_ids.blank?

        # Handle reversed relations (where this game is the target, not the source)
        if relation_type == :reimplemented_by
          create_reversed_game_relations(board_game, target_game_ids, :reimplements, game_data[:id])
        else
          create_game_relations(board_game, target_game_ids, relation_type, game_data[:id])
        end
      end

      board_game
    end

    def import_board_game(game_data, dry_run:, force_update: false)
      # Check if already imported
      existing = BggBoardGameAssociation.find_by(bgg_id: game_data[:id])

      if existing && !force_update
        return existing.board_game
      end

      # If updating an existing game, fetch it; otherwise create new
      board_game = existing&.board_game || BoardGame.new

      # Update attributes
      board_game.assign_attributes(
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

      # Create a BGG association if it doesn't exist
      unless existing
        board_game.create_bgg_board_game_association!(bgg_id: game_data[:id])
      end

      board_game
    end

    def find_board_games_by_bgg_ids(bgg_ids)
      # Fetch all games in a single query
      associations = BggBoardGameAssociation.where(bgg_id: bgg_ids).includes(:board_game)

      found_games = associations.map(&:board_game)
      found_bgg_ids = associations.map(&:bgg_id)
      not_found_ids = bgg_ids - found_bgg_ids

      [found_games, not_found_ids]
    end

    def create_game_relations(board_game, target_game_ids, relation_type, bgg_id)
      found_games, not_found_ids = find_board_games_by_bgg_ids(target_game_ids)

      if not_found_ids.any?
        Rails.logger.warn("Game #{bgg_id} has '#{relation_type}' links to non-imported games: #{not_found_ids.join(', ')}")
      end

      found_games.each do |target_game|
        BoardGameRelation.find_or_create_by!(
          source_game: board_game,
          target_game: target_game,
          relation_type: relation_type
        )
      end
    end

    def create_reversed_game_relations(board_game, source_game_ids, relation_type, bgg_id)
      found_games, not_found_ids = find_board_games_by_bgg_ids(source_game_ids)

      if not_found_ids.any?
        Rails.logger.warn("Game #{bgg_id} is '#{relation_type}' target for non-imported games: #{not_found_ids.join(', ')}")
      end

      found_games.each do |source_game|
        BoardGameRelation.find_or_create_by!(
          source_game: source_game,
          target_game: board_game,
          relation_type: relation_type
        )
      end
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

    def import_game_with_result(game_data, dry_run:, force_update:)
      bgg_id = game_data[:id]
      game_name = game_data[:name]

      # Check if already imported
      existing = BggBoardGameAssociation.find_by(bgg_id: bgg_id)

      if existing && !force_update
        return {
          status: :skipped,
          bgg_id: bgg_id,
          name: existing.board_game.name,
          reason: "Already imported"
        }
      end

      # Import or update the game
      game = import_game(game_data, dry_run: dry_run, force_update: force_update)

      if game
        status = existing ? :updated : :imported

        {
          status: status,
          bgg_id: bgg_id,
          board_game_id: game.id,
          name: game.name,
          rating: game.rating,
          year_published: game.year_published
        }
      else
        {
          status: :failed,
          bgg_id: bgg_id,
          name: game_name,
          error: "Import returned nil"
        }
      end
    rescue StandardError => e
      Rails.logger.error("Failed to import game #{bgg_id}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      {
        status: :failed,
        bgg_id: bgg_id,
        name: game_name,
        error: "#{e.class}: #{e.message}"
      }
    end
  end
end