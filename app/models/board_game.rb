class BoardGame < ApplicationRecord
  has_and_belongs_to_many :game_types
  has_and_belongs_to_many :game_categories
  has_many :extensions, dependent: :destroy

  validates :name, presence: true
  validates :min_players, presence: true, numericality: { greater_than: 0 }
  validates :max_players, presence: true
  validates :max_players, numericality: { greater_than_or_equal_to: :min_players }, if: :min_players
  validates :min_playing_time, numericality: { greater_than: 0 }, allow_nil: true
  validates :max_playing_time, numericality: { greater_than_or_equal_to: :min_playing_time }, allow_nil: true, if: :min_playing_time
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true
  validates :difficulty_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  validates :year_published, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :must_have_at_least_one_game_type
  validate :must_have_at_least_one_game_category

  scope :search_by_name, ->(name) { where("name ILIKE ?", "%#{name}%") if name.present? }
  scope :for_player_count, ->(player_count) {
    where("min_players <= ? AND max_players >= ?", player_count, player_count) if player_count.present?
  }
  scope :for_playing_time, ->(playing_time) {
    where("min_playing_time <= ? AND max_playing_time >= ?", playing_time, playing_time) if playing_time.present?
  }
  scope :max_playing_time_under, ->(max_time) {
    where("max_playing_time <= ?", max_time) if max_time.present?
  }
  scope :min_playing_time_over, ->(min_time) {
    where("min_playing_time >= ?", min_time) if min_time.present?
  }

  private

  def must_have_at_least_one_game_type
    if game_types.empty?
      errors.add(:game_types, "must have at least one game type")
    end
  end

  def must_have_at_least_one_game_category
    if game_categories.empty?
      errors.add(:game_categories, "must have at least one game category")
    end
  end
end