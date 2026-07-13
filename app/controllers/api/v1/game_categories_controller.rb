class Api::V1::GameCategoriesController < ApplicationController
  def index
    render json: { game_categories: GameCategory.order(:name).pluck(:name) }
  end
end
