module BoardGames
  class Serializer
    def self.serialize(board_game)
      new.serialize(board_game)
    end

    def self.serialize_collection(board_games)
      new.serialize_collection(board_games)
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
        extensions: serialize_extensions(board_game.extensions)
      }
    end

    def serialize_collection(board_games)
      {
        board_games: board_games.map { |game| serialize(game) },
        total: board_games.count
      }
    end

    private

    def serialize_extensions(extensions)
      extensions.map do |extension|
        {
          id: extension.id,
          name: extension.name,
          year_published: extension.year_published,
          min_players: extension.min_players,
          max_players: extension.max_players,
          min_playing_time: extension.min_playing_time,
          max_playing_time: extension.max_playing_time,
          rating: extension.rating,
          rating_count: extension.rating_count,
          difficulty_score: extension.difficulty_score
        }
      end
    end
  end
end