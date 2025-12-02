module BoardGames
  module Details
    class Serializer
      def self.serialize(board_game)
        new.serialize(board_game)
      end

      def serialize(board_game)
        {
          id: board_game.id,
          name: board_game.name,
          year_published: board_game.year_published,
          game_types: board_game.game_types.map(&:name),
          game_categories: board_game.game_categories.map(&:name),
          min_players: board_game.min_players,
          max_players: board_game.max_players,
          min_playing_time: board_game.min_playing_time,
          max_playing_time: board_game.max_playing_time,
          rating: board_game.rating,
          rating_count: board_game.rating_count,
          difficulty_score: board_game.difficulty_score,
          expansions: serialize_expansions(board_game.expansions)
        }
      end

      private

      def serialize_expansions(expansions)
        expansions.map do |expansion|
          {
            id: expansion.id,
            name: expansion.name,
            year_published: expansion.year_published,
            min_players: expansion.min_players,
            max_players: expansion.max_players,
            min_playing_time: expansion.min_playing_time,
            max_playing_time: expansion.max_playing_time,
            rating: expansion.rating,
            rating_count: expansion.rating_count,
            difficulty_score: expansion.difficulty_score
          }
        end
      end
    end
  end
end
