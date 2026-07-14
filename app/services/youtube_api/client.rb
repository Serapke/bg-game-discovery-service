# frozen_string_literal: true

require "faraday"

module YoutubeApi
  # Client for the YouTube Data API v3 (videos.list).
  # Documentation: https://developers.google.com/youtube/v3/docs/videos/list
  class Client
    class Error < StandardError; end
    class TimeoutError < Error; end
    class ApiError < Error; end
    class ParseError < Error; end

    # Fetch stats/status for a set of YouTube video IDs.
    #
    # @param youtube_ids [Array<String>] YouTube video IDs (chunked to 50 per request)
    #
    # @return [Hash<String, Hash>] keyed by youtube_video_id. IDs that YouTube omits
    #   from the response (deleted/unavailable) are simply absent from the hash.
    #   {
    #     "<id>" => {
    #       duration_seconds:, view_count:, like_count:, comment_count:,
    #       thumbnail_url:, privacy_status:, upload_status:
    #     }
    #   }
    #
    # @raise [Error] on quota exceeded, timeout, network, or parse failure — callers
    #   treat any raise as fail-soft (keep link-only rows, retry next import).
    def get_video_details(youtube_ids)
      ids = Array(youtube_ids).compact.uniq
      return {} if ids.empty?

      raise ApiError, "YOUTUBE_API_KEY is not configured" if YoutubeApi::API_KEY.blank?

      result = {}
      ids.each_slice(YoutubeApi::MAX_IDS_PER_CALL) do |chunk|
        body = get("videos", {
          part: "snippet,statistics,contentDetails,status",
          id: chunk.join(","),
          key: YoutubeApi::API_KEY
        })
        parse_video_details(body).each { |id, data| result[id] = data }
      end
      result
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Timeout::Error => e
      raise TimeoutError, "Request to YouTube API timed out: #{e.message}"
    rescue Faraday::Error => e
      raise ApiError, "YouTube API request failed: #{e.message}"
    end

    private

    def connection
      @connection ||= Faraday.new(
        url: YoutubeApi::BASE_URL,
        request: {
          timeout: YoutubeApi::TIMEOUT,
          open_timeout: YoutubeApi::OPEN_TIMEOUT
        }
      ) do |f|
        f.response :json
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def get(path, params = {})
      connection.get(path, params).body
    end

    def parse_video_details(body)
      items = body.is_a?(Hash) ? body["items"] : nil
      raise ParseError, "Unexpected YouTube API response" unless items.is_a?(Array)

      items.each_with_object({}) do |item, acc|
        id = item["id"]
        next if id.blank?

        snippet = item["snippet"] || {}
        stats = item["statistics"] || {}
        content = item["contentDetails"] || {}
        status = item["status"] || {}

        acc[id] = {
          duration_seconds: parse_iso8601_duration(content["duration"]),
          view_count: stats["viewCount"]&.to_i,
          like_count: stats["likeCount"]&.to_i,
          comment_count: stats["commentCount"]&.to_i,
          thumbnail_url: snippet.dig("thumbnails", "high", "url"),
          privacy_status: status["privacyStatus"],
          upload_status: status["uploadStatus"]
        }
      end
    end

    # Convert an ISO-8601 duration (e.g. "PT1H2M10S") to whole seconds.
    # Returns nil for a blank/unparseable value.
    def parse_iso8601_duration(iso)
      return nil if iso.blank?

      ActiveSupport::Duration.parse(iso).to_i
    rescue ArgumentError
      nil
    end
  end
end
