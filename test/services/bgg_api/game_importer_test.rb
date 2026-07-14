# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"
require "minitest/mock"

module BggApi
  class GameImporterTest < ActiveSupport::TestCase
    # Most of import_by_ids is covered by integration tests and the
    # SearchImporter tests. These focus on the videos sync introduced with
    # instructional-video import (phase 1).

    # Stub YouTube client: returns whatever details hash it's configured with, or
    # raises to simulate quota/outage (fail-soft path). Records the IDs it was asked
    # about so tests can assert on them.
    class StubYoutubeClient
      attr_reader :requested_ids

      def initialize(details: {}, raise_error: nil)
        @details = details
        @raise_error = raise_error
        @requested_ids = nil
      end

      def get_video_details(ids)
        @requested_ids = ids
        raise @raise_error if @raise_error

        @details
      end
    end

    def public_detail(overrides = {})
      {
        duration_seconds: 600,
        view_count: 50_000,
        like_count: 100,
        comment_count: 10,
        thumbnail_url: "https://img.youtube.com/vi/x/hqdefault.jpg",
        privacy_status: "public",
        upload_status: "processed"
      }.merge(overrides)
    end

    setup do
      @client = Minitest::Mock.new
      @youtube_client = StubYoutubeClient.new
      @importer = BggApi::GameImporter.new(client: @client, youtube_client: @youtube_client)
    end

    def game_data(bgg_id: 13)
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
        links: {}
      }
    end

    def import(videos:, youtube_client: nil)
      importer = youtube_client ? BggApi::GameImporter.new(client: @client, youtube_client: youtube_client) : @importer
      @client.expect(:get_details, [game_data], [[13], { min_user_ratings: 1_000 }])
      # Videos now come from the AJAX videos endpoint, not the thing response.
      @client.expect(:get_videos, videos, [13])
      importer.import_by_ids([13], skip_recommendations: true, force_update: true)
    end

    test "import persists filtered instructional videos" do
      video = {
        youtube_video_id: "8Nx6Jij2q3s",
        link: "https://www.youtube.com/watch?v=8Nx6Jij2q3s",
        title: "How to Play Catan",
        category: "instructional",
        language: "English"
      }
      youtube = StubYoutubeClient.new(details: { "8Nx6Jij2q3s" => public_detail })

      assert_difference -> { Video.count }, 1 do
        import(videos: [video], youtube_client: youtube)
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

      youtube = StubYoutubeClient.new(details: { "8Nx6Jij2q3s" => public_detail })
      import(videos: [video], youtube_client: youtube)

      # Second import of the same game+video should update in place, not duplicate.
      assert_no_difference -> { Video.count } do
        import(videos: [{ **video, title: "How to Play Catan (updated)" }], youtube_client: youtube)
      end

      assert_equal "How to Play Catan (updated)",
                   Video.find_by(youtube_video_id: "8Nx6Jij2q3s").title
    end

    test "import with no videos creates no video rows" do
      assert_no_difference -> { Video.count } do
        import(videos: [])
      end
    end

    # --- Phase 2: YouTube enrichment ---

    test "enrichment fills in stats for public processed videos" do
      video = {
        youtube_video_id: "abc12345678",
        link: "https://www.youtube.com/watch?v=abc12345678",
        title: "How to Play",
        category: "instructional",
        language: "English"
      }
      youtube = StubYoutubeClient.new(details: {
        "abc12345678" => public_detail(duration_seconds: 3730, view_count: 42_000)
      })

      import(videos: [video], youtube_client: youtube)

      persisted = Video.find_by(youtube_video_id: "abc12345678")
      assert_equal 3730, persisted.duration_seconds
      assert_equal 42_000, persisted.view_count
      assert_not_nil persisted.enriched_at
      assert_equal ["abc12345678"], youtube.requested_ids
    end

    test "non-public videos are removed during enrichment" do
      video = {
        youtube_video_id: "priv1234567",
        link: "https://www.youtube.com/watch?v=priv1234567",
        title: "Private video",
        category: "instructional",
        language: "English"
      }
      youtube = StubYoutubeClient.new(details: {
        "priv1234567" => public_detail(privacy_status: "private")
      })

      assert_no_difference -> { Video.count } do
        import(videos: [video], youtube_client: youtube)
      end
      assert_nil Video.find_by(youtube_video_id: "priv1234567")
    end

    test "videos below the view-count floor are removed during enrichment" do
      video = {
        youtube_video_id: "lowv1234567",
        link: "https://www.youtube.com/watch?v=lowv1234567",
        title: "Barely watched",
        category: "instructional",
        language: "English"
      }
      # Just below the 10k floor (would have passed the old 1k floor).
      youtube = StubYoutubeClient.new(details: {
        "lowv1234567" => public_detail(view_count: 9_999)
      })

      assert_no_difference -> { Video.count } do
        import(videos: [video], youtube_client: youtube)
      end
      assert_nil Video.find_by(youtube_video_id: "lowv1234567")
    end

    test "public videos with a nil view count are removed" do
      video = {
        youtube_video_id: "nilv1234567",
        link: "https://www.youtube.com/watch?v=nilv1234567",
        title: "Hidden view count",
        category: "instructional",
        language: "English"
      }
      youtube = StubYoutubeClient.new(details: {
        "nilv1234567" => public_detail(view_count: nil)
      })

      assert_no_difference -> { Video.count } do
        import(videos: [video], youtube_client: youtube)
      end
      assert_nil Video.find_by(youtube_video_id: "nilv1234567")
    end

    test "videos absent from the YouTube response are removed" do
      video = {
        youtube_video_id: "gone1234567",
        link: "https://www.youtube.com/watch?v=gone1234567",
        title: "Deleted video",
        category: "instructional",
        language: "English"
      }
      # Empty details => YouTube returned nothing for this ID (deleted).
      youtube = StubYoutubeClient.new(details: {})

      assert_no_difference -> { Video.count } do
        import(videos: [video], youtube_client: youtube)
      end
      assert_nil Video.find_by(youtube_video_id: "gone1234567")
    end

    test "enrichment fails soft when the YouTube call raises" do
      video = {
        youtube_video_id: "soft1234567",
        link: "https://www.youtube.com/watch?v=soft1234567",
        title: "Link only",
        category: "instructional",
        language: "English"
      }
      youtube = StubYoutubeClient.new(raise_error: YoutubeApi::Client::ApiError.new("quota exceeded"))

      # Row is kept (link-only), not deleted, and import still succeeds.
      assert_difference -> { Video.count }, 1 do
        import(videos: [video], youtube_client: youtube)
      end
      persisted = Video.find_by(youtube_video_id: "soft1234567")
      assert_nil persisted.enriched_at
      assert_nil persisted.view_count
    end
  end
end
