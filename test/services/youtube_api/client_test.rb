# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module YoutubeApi
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = YoutubeApi::Client.new
      @base_url = YoutubeApi::BASE_URL.chomp("/")
      @original_key = YoutubeApi::API_KEY
      set_api_key("test-key")
    end

    teardown do
      set_api_key(@original_key)
    end

    def set_api_key(value)
      YoutubeApi.send(:remove_const, :API_KEY) if YoutubeApi.const_defined?(:API_KEY)
      YoutubeApi.const_set(:API_KEY, value)
    end

    def stub_videos(items)
      stub_request(:get, "#{@base_url}/videos")
        .with(query: hash_including("part" => "snippet,statistics,contentDetails,status"))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { items: items }.to_json
        )
    end

    test "returns {} for empty ids without calling the API" do
      assert_equal({}, @client.get_video_details([]))
      assert_not_requested :get, "#{@base_url}/videos"
    end

    test "parses stats, duration, and status keyed by id" do
      stub_videos([
        {
          id: "abc12345678",
          snippet: { thumbnails: { high: { url: "https://img/hq.jpg" } } },
          statistics: { viewCount: "42000", likeCount: "500", commentCount: "12" },
          contentDetails: { duration: "PT1H2M10S" },
          status: { privacyStatus: "public", uploadStatus: "processed" }
        }
      ])

      result = @client.get_video_details(["abc12345678"])
      data = result["abc12345678"]

      assert_equal 3730, data[:duration_seconds]
      assert_equal 42_000, data[:view_count]
      assert_equal 500, data[:like_count]
      assert_equal 12, data[:comment_count]
      assert_equal "https://img/hq.jpg", data[:thumbnail_url]
      assert_equal "public", data[:privacy_status]
      assert_equal "processed", data[:upload_status]
    end

    test "ids absent from the response are absent from the result" do
      stub_videos([])
      assert_equal({}, @client.get_video_details(["missing1234"]))
    end

    test "raises ApiError when the API key is not configured" do
      set_api_key(nil)
      assert_raises(YoutubeApi::Client::ApiError) do
        @client.get_video_details(["abc12345678"])
      end
    end

    test "raises ApiError on an HTTP error (e.g. quota exceeded)" do
      stub_request(:get, "#{@base_url}/videos").with(query: hash_including({}))
        .to_return(status: 403, body: "quotaExceeded")
      assert_raises(YoutubeApi::Client::ApiError) do
        @client.get_video_details(["abc12345678"])
      end
    end

    test "raises TimeoutError on a timeout" do
      stub_request(:get, "#{@base_url}/videos").with(query: hash_including({})).to_timeout
      assert_raises(YoutubeApi::Client::TimeoutError) do
        @client.get_video_details(["abc12345678"])
      end
    end
  end
end
