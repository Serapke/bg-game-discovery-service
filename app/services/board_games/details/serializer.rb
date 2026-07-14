module BoardGames
  module Details
    class Serializer
      RELATION_KEYS = %i[
        expansions
        base_games
        contained_games
        containers
        reimplemented_games
        reimplementations
        integrated_games
      ].freeze

      def self.serialize(board_game)
        new.serialize(board_game)
      end

      def serialize(board_game)
        payload = {
          id: board_game.id,
          name: board_game.name,
          description: board_game.description,
          year_published: board_game.year_published,
          game_types: board_game.game_types.map(&:name),
          game_categories: board_game.game_categories.map(&:name),
          min_players: board_game.min_players,
          max_players: board_game.max_players,
          best_min_players: board_game.best_min_players,
          best_max_players: board_game.best_max_players,
          min_playing_time: board_game.min_playing_time,
          max_playing_time: board_game.max_playing_time,
          rating: board_game.rating,
          rating_count: board_game.rating_count,
          difficulty_score: board_game.difficulty_score,
          image_url: board_game.image_url,
          thumbnail_url: board_game.thumbnail_url,
          videos: serialize_videos(board_game)
        }

        RELATION_KEYS.each do |key|
          payload[key] = serialize_summary(board_game.public_send(key))
        end

        payload
      end

      private

      # Only enriched (public, playable) videos, most-watched first.
      def serialize_videos(board_game)
        board_game.videos
          .where.not(enriched_at: nil)
          .order(Arel.sql("view_count DESC NULLS LAST"))
          .map do |video|
            {
              id: video.id,
              youtube_video_id: video.youtube_video_id,
              link: video.link,
              title: video.title,
              category: video.category,
              language: video.language,
              duration_seconds: video.duration_seconds,
              view_count: video.view_count,
              like_count: video.like_count,
              comment_count: video.comment_count,
              thumbnail_url: video.thumbnail_url
            }
          end
      end

      def serialize_summary(games)
        games.map do |game|
          {
            id: game.id,
            name: game.name,
            year_published: game.year_published,
            min_players: game.min_players,
            max_players: game.max_players,
            min_playing_time: game.min_playing_time,
            max_playing_time: game.max_playing_time,
            rating: game.rating,
            rating_count: game.rating_count,
            difficulty_score: game.difficulty_score,
            image_url: game.image_url,
            thumbnail_url: game.thumbnail_url
          }
        end
      end
    end
  end
end
