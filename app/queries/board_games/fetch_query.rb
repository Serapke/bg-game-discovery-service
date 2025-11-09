module BoardGames
  class FetchQuery
    def initialize(relation = BoardGame.all)
      @relation = relation
    end

    def call(ids: nil)
      if ids
        fetch_by_ids(ids)
      else
        fetch_all
      end
    end

    def fetch_by_ids(ids)
      raise ArgumentError, 'No valid IDs provided' if ids.empty?

      @relation.includes(:extensions, :game_types, :game_categories).where(id: ids)
    end

    def fetch_all
      @relation.includes(:extensions, :game_types, :game_categories).all
    end
  end
end