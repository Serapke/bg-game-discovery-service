module BoardGames
  class SearchQuery
    VALID_GAME_TYPES = %w[abstract family party strategy thematic].freeze

    def initialize(relation = BoardGame.all, importer: nil)
      @relation = relation
      @importer = importer || BggApi::SearchImporter.new
    end

    def call(params)
      validate_params!(params)

      scope = build_scope(params)

      # If no results found, try importing from BGG and search again
      if scope.empty?
        import_from_bgg(params[:name])
        scope = build_scope(params)
      end

      scope
    end

    private

    def validate_params!(params)
      if params.key?(:name) && params[:name].blank?
        raise ArgumentError, 'Name parameter cannot be empty'
      end

      if params[:game_types].present?
        types = extract_game_types(params)
        invalid = types - VALID_GAME_TYPES
        raise ArgumentError, "Invalid game type(s): #{invalid.join(', ')}. Valid values: #{VALID_GAME_TYPES.join(', ')}" if invalid.any?
      end
    end

    def build_scope(params)
      scope = @relation.includes(:game_types, :game_categories)
      scope = apply_name_filter(scope, params[:name])
      scope = apply_player_count_filter(scope, params[:player_count])
      scope = apply_playing_time_filters(scope, params)
      types = extract_game_types(params)
      scope = scope.with_game_types(types) if types.any?
      scope = scope.with_min_rating(params[:min_rating]) if params[:min_rating].present?
      scope
    end

    def extract_game_types(params)
      raw = params[:game_types]
      return [] if raw.blank?
      Array(raw).flat_map { |t| t.to_s.split(',') }.map { |t| t.strip.downcase }.reject(&:blank?).uniq
    end

    def import_from_bgg(query)
      @importer.import_from_search(query)
    rescue BggApi::SearchImporter::ImportError => e
      # Log the error but don't fail the search
      Rails.logger.error("Failed to import games from BGG: #{e.message}")
      []
    end

    def apply_name_filter(scope, name)
      return scope if name.blank?
      scope.search_by_name(name)
    end

    def apply_player_count_filter(scope, player_count)
      return scope if player_count.blank?
      scope.for_player_count(player_count)
    end

    def apply_playing_time_filters(scope, params)
      scope = scope.for_playing_time(params[:playing_time]) if params[:playing_time].present?
      scope = scope.max_playing_time_under(params[:max_playing_time]) if params[:max_playing_time].present?
      scope = scope.min_playing_time_over(params[:min_playing_time]) if params[:min_playing_time].present?
      scope
    end
  end
end