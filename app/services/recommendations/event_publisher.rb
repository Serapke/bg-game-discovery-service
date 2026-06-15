# frozen_string_literal: true

module Recommendations
  class EventPublisher
    RECOMMENDER_SERVICE_URL = ENV.fetch("RECOMMENDER_SERVICE_URL", "http://localhost:3004").freeze

    def publish(game_id:, recommended_game_ids:)
      return if recommended_game_ids.empty?

      conn = Faraday.new(url: RECOMMENDER_SERVICE_URL)
      conn.post("/api/v1/events/recommendations_updated") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = { game_id: game_id, recommended_game_ids: recommended_game_ids }.to_json
      end
    rescue Faraday::Error => e
      Rails.logger.error("Failed to publish recommendations event for game #{game_id}: #{e.message}")
    end
  end
end
