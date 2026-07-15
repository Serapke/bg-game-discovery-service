class Api::V1::GamePhotosController < ApplicationController
  before_action :set_board_game

  def index
    photos = @board_game.game_photos.with_attached_image.order(:created_at)
    render json: ::GamePhotos::Serializer.serialize_collection(
      photos, url_helpers: self, host: request.base_url
    )
  end

  def create
    unless params[:image].present?
      return render json: { error: 'No image provided' }, status: :bad_request
    end

    photo = @board_game.game_photos.new
    photo.image.attach(params[:image])

    if photo.save
      render json: ::GamePhotos::Serializer.serialize(
        photo, url_helpers: self, host: request.base_url
      ), status: :created
    else
      render json: { errors: photo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    photo = @board_game.game_photos.find(params[:id])
    photo.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Photo not found' }, status: :not_found
  end

  private

  def set_board_game
    @board_game = BoardGame.find(params[:board_game_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Board game not found' }, status: :not_found
  end
end
