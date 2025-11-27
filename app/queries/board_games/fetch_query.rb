module BoardGames
  class FetchQuery
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

    private

    def fetch_by_ids(ids)
      raise ArgumentError, 'No valid IDs provided' if ids.empty?

      @relation.includes(:extensions, :game_types, :game_categories).where(id: ids)
    end

    def fetch_all
      @relation.includes(:extensions, :game_types, :game_categories).all
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