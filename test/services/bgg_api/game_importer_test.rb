# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"
require "minitest/mock"

module BggApi
  class GameImporterTest < ActiveSupport::TestCase
    # Most of import_by_ids is covered by integration tests and the
    # SearchImporter tests. These focus on the videos sync introduced with
    # instructional-video import (phase 1).

    setup do
      @client = Minitest::Mock.new
      @importer = BggApi::GameImporter.new(client: @client)
    end

    def game_data(videos:, bgg_id: 13)
      {
        id: bgg_id,
        thing_type: "boardgame",
        types: [],
        name: "Catan",
        year_published: 1995,
        min_players: 3,
        max_players: 4,
        min_playing_time: 60,
        max_playing_time: 120,
        rating: 7.12,
        complexity: 2.35,
        user_ratings_count: 50_000,
        categories: [],
        mechanics: [],
        links: {},
        videos: videos
      }
    end

    def import(videos:)
      @client.expect(:get_details, [game_data(videos: videos)], [[13], { min_user_ratings: 1_000 }])
      @importer.import_by_ids([13], skip_recommendations: true, force_update: true)
    end

    test "import persists filtered instructional videos" do
      video = {
        youtube_video_id: "8Nx6Jij2q3s",
        link: "https://www.youtube.com/watch?v=8Nx6Jij2q3s",
        title: "How to Play Catan",
        category: "instructional",
        language: "English"
      }

      assert_difference -> { Video.count }, 1 do
        import(videos: [video])
      end

      persisted = Video.find_by(youtube_video_id: "8Nx6Jij2q3s")
      assert_equal "How to Play Catan", persisted.title
      assert_equal "https://www.youtube.com/watch?v=8Nx6Jij2q3s", persisted.link

      @client.verify
    end

    test "re-import with force_update does not duplicate videos" do
      video = {
        youtube_video_id: "8Nx6Jij2q3s",
        link: "https://www.youtube.com/watch?v=8Nx6Jij2q3s",
        title: "How to Play Catan",
        category: "instructional",
        language: "English"
      }

      import(videos: [video])

      # Second import of the same game+video should update in place, not duplicate.
      assert_no_difference -> { Video.count } do
        import(videos: [{ **video, title: "How to Play Catan (updated)" }])
      end

      assert_equal "How to Play Catan (updated)",
                   Video.find_by(youtube_video_id: "8Nx6Jij2q3s").title
    end

    test "import with no videos creates no video rows" do
      assert_no_difference -> { Video.count } do
        import(videos: [])
      end
    end
  end
end
