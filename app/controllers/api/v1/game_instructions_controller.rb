class Api::V1::GameInstructionsController < ApplicationController
  before_action :set_board_game

  def index
    instructions = @board_game.game_instructions
      .with_attached_document
      .order(:language, :category, :created_at)
    render json: ::GameInstructions::Serializer.serialize_collection(
      instructions, url_helpers: self, host: request.base_url
    )
  end

  def create
    unless params[:document].present?
      return render json: { error: 'No document provided' }, status: :bad_request
    end

    instruction = @board_game.game_instructions.new(
      language: params[:language],
      category: params[:category]
    )
    instruction.document.attach(params[:document])

    if instruction.save
      render json: ::GameInstructions::Serializer.serialize(
        instruction, url_helpers: self, host: request.base_url
      ), status: :created
    elsif duplicate_combo?(instruction)
      render json: { errors: instruction.errors.full_messages }, status: :conflict
    else
      render json: { errors: instruction.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    instruction = @board_game.game_instructions.find(params[:id])
    instruction.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Instruction not found' }, status: :not_found
  end

  private

  # A repeat upload for a game + language + category that already has a file is a
  # conflict (409), distinct from a genuinely invalid upload (422).
  def duplicate_combo?(instruction)
    instruction.errors.of_kind?(:category, :taken)
  end

  def set_board_game
    @board_game = BoardGame.find(params[:board_game_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Board game not found' }, status: :not_found
  end
end
