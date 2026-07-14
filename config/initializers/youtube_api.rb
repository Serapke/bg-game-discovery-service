# frozen_string_literal: true

# YouTube Data API v3 configuration
# Documentation: https://developers.google.com/youtube/v3/docs/videos/list
module YoutubeApi
  BASE_URL = ENV.fetch("YOUTUBE_API_BASE_URL", "https://www.googleapis.com/youtube/v3/").freeze
  API_KEY = ENV.fetch("YOUTUBE_API_KEY", nil).freeze
  TIMEOUT = ENV.fetch("YOUTUBE_API_TIMEOUT", 10).to_i
  OPEN_TIMEOUT = ENV.fetch("YOUTUBE_API_OPEN_TIMEOUT", 5).to_i

  # videos.list accepts up to 50 IDs per request (1 quota unit per call).
  MAX_IDS_PER_CALL = 50
end
