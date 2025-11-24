class Api::V1::BoardGamesController < ApplicationController
  def index
    ids = parse_ids if params.key?(:ids)

    if ids&.empty?
      render json: { error: 'No valid IDs provided' }, status: :bad_request
      return
    end

    board_games = ::BoardGames::FetchQuery.new.call(ids: ids)
    render json: ::BoardGames::Serializer.serialize_collection(board_games)
  end

  def show
    board_game = BoardGame.includes(:extensions, :game_types, :game_categories).find(params[:id])
    render json: ::BoardGames::Serializer.serialize(board_game)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Board game not found' }, status: :not_found
  end

  def search
    board_games = ::BoardGames::SearchQuery.new.call(params)
    render json: ::BoardGames::Serializer.serialize_collection(board_games)
  rescue ArgumentError => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def parse_ids
    params[:ids].to_s.split(',').map(&:to_i).reject(&:zero?)
  end
end