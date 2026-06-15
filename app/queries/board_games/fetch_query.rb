module BoardGames
  class FetchQuery
    VALID_SORTS = %w[recommended rating rating_count difficulty].freeze
    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 50

    def initialize(relation = BoardGame.all)
      @relation = relation
    end

    def call(ids: nil, player_count: nil, max_playing_time: nil, game_types: nil, min_rating: nil)
      scope = if ids
        fetch_by_ids(ids)
      else
        fetch_all
      end

      apply_filters(scope, player_count: player_count, max_playing_time: max_playing_time, game_types: game_types, min_rating: min_rating)
    end

    def paginated(sort:, page:, per_page:, player_count: nil, max_playing_time: nil, game_types: nil, min_rating: nil)
      sort = sort.to_s.presence || 'recommended'
      raise ArgumentError, "Invalid sort: #{sort.inspect}. Valid: #{VALID_SORTS.join(', ')}" unless VALID_SORTS.include?(sort)

      page = [page.to_i, 1].max
      per_page = per_page.to_i
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      per_page = [per_page, MAX_PER_PAGE].min

      base = @relation.includes(:game_types, :game_categories)
      filtered = apply_filters(base, player_count: player_count, max_playing_time: max_playing_time, game_types: game_types, min_rating: min_rating)
      ordered = filtered.reorder(order_clause(sort))
      total = filtered.except(:includes, :order).count(:id)
      records = ordered.limit(per_page).offset((page - 1) * per_page).to_a

      { records: records, total: total, page: page, per_page: per_page, total_pages: (total.to_f / per_page).ceil }
    end

    private

    def order_clause(sort)
      case sort
      when 'rating'
        Arel.sql('board_games.rating DESC NULLS LAST, board_games.id ASC')
      when 'rating_count'
        Arel.sql('board_games.rating_count DESC NULLS LAST, board_games.id ASC')
      when 'difficulty'
        Arel.sql('board_games.difficulty_score DESC NULLS LAST, board_games.id ASC')
      else # 'recommended'
        Arel.sql(<<~SQL.squish)
          (0.7 * COALESCE(board_games.rating, 0) / 10.0
           + 0.3 * LN(1 + COALESCE(board_games.rating_count, 0))
                 / GREATEST(LN(1 + (SELECT MAX(rating_count) FROM board_games)), 1)
          ) DESC, board_games.id ASC
        SQL
      end
    end

    def fetch_by_ids(ids)
      raise ArgumentError, 'No valid IDs provided' if ids.empty?

      @relation.includes(:game_types, :game_categories).where(id: ids)
    end

    def fetch_all
      @relation.includes(:game_types, :game_categories).all
    end

    def apply_filters(scope, player_count:, max_playing_time:, game_types:, min_rating:)
      scope = scope.for_player_count(player_count) if player_count.present?
      scope = scope.max_playing_time_under(max_playing_time) if max_playing_time.present?
      scope = scope.with_game_types(game_types) if game_types.present?
      scope = scope.with_min_rating(min_rating) if min_rating.present?
      scope
    end
  end
end
