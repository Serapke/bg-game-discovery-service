module BoardGames
  class SearchQuery
    VALID_GAME_TYPES = %w[abstract family party strategy thematic].freeze

    # True when the BGG fallback enqueued background import jobs, meaning more
    # matches may appear on a subsequent request once those jobs finish.
    attr_reader :importing

    def initialize(relation = BoardGame.all, importer: nil)
      @relation = relation
      @importer = importer || BggApi::SearchImporter.new
      @importing = false
    end

    def call(params)
      validate_params!(params)

      scope = build_scope(params)

      # If fewer than 5 results found, try importing from BGG and search again
      if params[:name].present? && scope.count < 5
        import_from_bgg(params[:name])
        scope = build_scope(params)
      end

      scope
    end

    alias importing? importing

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
      categories = extract_game_categories(params)
      scope = scope.with_game_categories(categories) if categories.any?
      scope = scope.with_min_rating(params[:min_rating]) if params[:min_rating].present?
      apply_search_ordering(scope, params[:name])
    end

    # Order results so base games rank ahead of their expansions, and within
    # each group by relevance to the typed query, then name.
    #
    # A game counts as an expansion when it has an outgoing +expands+ relation
    # (its id appears as source_game_id in board_game_relations). A correlated
    # EXISTS subquery is used rather than a LEFT JOIN so games with multiple base
    # games don't produce duplicate rows.
    #
    # The relevance tier keeps an exact name match ahead of prefix matches, and
    # prefix matches ahead of games that merely contain the query. Without it,
    # a plain name sort surfaces e.g. "A Game of Thrones: Catan" above "Catan"
    # for the query "catan". Only applied when a name filter is present.
    def apply_search_ordering(scope, name)
      scope = scope.order(Arel.sql(<<~SQL.squish))
        (CASE WHEN EXISTS (
           SELECT 1 FROM board_game_relations r
           WHERE r.source_game_id = board_games.id
             AND r.relation_type = 'expands') THEN 1 ELSE 0 END) ASC
      SQL

      if name.present?
        scope = scope.order(
          Arel.sql(sanitize_sql([<<~SQL.squish, { exact: name, prefix: "#{name}%" }]))
            (CASE
               WHEN board_games.name ILIKE :exact THEN 0
               WHEN board_games.name ILIKE :prefix THEN 1
               ELSE 2 END) ASC
          SQL
        )
      end

      scope.order(Arel.sql('board_games.name ASC'))
    end

    def sanitize_sql(condition)
      ActiveRecord::Base.sanitize_sql_array(condition)
    end

    def extract_game_categories(params)
      raw = params[:game_categories]
      return [] if raw.blank?
      Array(raw).flat_map { |c| c.to_s.split(',') }.map(&:strip).reject(&:blank?).uniq
    end

    def extract_game_types(params)
      raw = params[:game_types]
      return [] if raw.blank?
      Array(raw).flat_map { |t| t.to_s.split(',') }.map { |t| t.strip.downcase }.reject(&:blank?).uniq
    end

    def import_from_bgg(query)
      result = @importer.import_from_search(query)
      @importing = result.is_a?(Hash) && result[:importing] == true
      result
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