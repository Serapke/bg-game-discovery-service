class Api::V1::BoardGamesController < ApplicationController
  before_action :set_board_game, only: [:show]

  def index
    if params.key?(:ids)
      # Fetch specific games by IDs
      ids = params[:ids].to_s.split(',').map(&:to_i).reject(&:zero?)

      if ids.empty?
        render json: { error: 'No valid IDs provided' }, status: :bad_request
        return
      end

      @board_games = BoardGame.includes(:extensions).where(id: ids)
    else
      @board_games = BoardGame.includes(:extensions).all
    end

    render json: {
      board_games: @board_games.map { |game| board_game_json(game) },
      total: @board_games.count
    }
  end

  def show
    render json: board_game_json(@board_game)
  end

  def search
    board_games = BoardGame.includes(:extensions)
    board_games = board_games.search_by_name(params[:name]) if params[:name].present?
    board_games = board_games.for_player_count(params[:player_count]) if params[:player_count].present?
    board_games = board_games.for_playing_time(params[:playing_time]) if params[:playing_time].present?
    board_games = board_games.max_playing_time_under(params[:max_playing_time]) if params[:max_playing_time].present?
    board_games = board_games.min_playing_time_over(params[:min_playing_time]) if params[:min_playing_time].present?

    render json: {
      board_games: board_games.map { |game| board_game_json(game) },
      total: board_games.count
    }
  end

  private

  def set_board_game
    @board_game = BoardGame.includes(:extensions).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Board game not found' }, status: :not_found
  end

  def board_game_json(board_game)
    {
      id: board_game.id,
      name: board_game.name,
      min_players: board_game.min_players,
      max_players: board_game.max_players,
      min_playing_time: board_game.min_playing_time,
      max_playing_time: board_game.max_playing_time,
      rating: board_game.rating,
      extensions: board_game.extensions.map do |extension|
        {
          id: extension.id,
          name: extension.name,
          min_players: extension.min_players,
          max_players: extension.max_players,
          min_playing_time: extension.min_playing_time,
          max_playing_time: extension.max_playing_time,
          rating: extension.rating
        }
      end
    }
  end
end