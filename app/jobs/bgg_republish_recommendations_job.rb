# frozen_string_literal: true

# Re-publishes a game's BGG recommendations after BggGameRefreshJob has imported the
# previously-missing recommended games. The initial publish that ran during the seed
# import skipped those games because they didn't have local board_game_ids yet.
class BggRepublishRecommendationsJob < ApplicationJob
  queue_as :default

  retry_on BggApi::Client::TimeoutError, wait: :exponentially_longer, attempts: 3
  retry_on BggApi::Client::ApiError, wait: :exponentially_longer, attempts: 3

  def perform(bgg_id)
    association = BggBoardGameAssociation.find_by(bgg_id: bgg_id)
    return unless association

    BggApi::GameImporter.new.publish_recommendations_for(association.board_game_id, bgg_id)
  end
end
