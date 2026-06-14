class Api::V1::BoardGamesController < ApplicationController
  def index
    ids = parse_ids if params.key?(:ids)

    if ids&.empty?
      render json: { error: 'No valid IDs provided' }, status: :bad_request
      return
    end

    board_games = ::BoardGames::FetchQuery.new.call(
      ids: ids,
      player_count: params[:player_count],
      max_playing_time: params[:max_playing_time],
      game_types: parse_game_types,
      min_rating: params[:min_rating]
    )
    render json: ::BoardGames::Serializer.serialize_collection(board_games)
  end

  def show
    board_game = BoardGame.includes(:expansions, :game_types, :game_categories).find(params[:id])
    render json: ::BoardGames::Details::Serializer.serialize(board_game)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Board game not found' }, status: :not_found
  end

  def search
    board_games = ::BoardGames::SearchQuery.new.call(params)
    render json: ::BoardGames::Serializer.serialize_collection(board_games)
  rescue ArgumentError => e
    render json: { error: e.message }, status: :bad_request
  end

  TRENDING_CACHE_KEY = 'bgg:hot:boardgame'
  TRENDING_CACHE_TTL = 1.week

  def trending
    bgg_ids = Rails.cache.fetch(TRENDING_CACHE_KEY, expires_in: TRENDING_CACHE_TTL) do
      ::BggApi::HotImporter.new.import_hot[:all_ids]
    end

    board_games = ordered_board_games_for_bgg_ids(bgg_ids)
    render json: ::BoardGames::Serializer.serialize_collection(board_games)
  rescue ::BggApi::HotImporter::ImportError => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

  def ordered_board_games_for_bgg_ids(bgg_ids)
    return [] if bgg_ids.blank?

    associations = BggBoardGameAssociation
      .where(bgg_id: bgg_ids)
      .includes(board_game: [:game_types, :game_categories])

    by_bgg_id = associations.each_with_object({}) { |a, acc| acc[a.bgg_id] = a.board_game }
    bgg_ids.map { |id| by_bgg_id[id] }.compact
  end

  def parse_ids
    params[:ids].to_s.split(',').map(&:to_i).reject(&:zero?)
  end

  def parse_game_types
    return nil unless params[:game_types].present?
    params[:game_types].to_s.split(',').map(&:strip).reject(&:blank?)
  end
end