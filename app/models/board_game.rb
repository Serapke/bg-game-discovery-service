class BoardGame < ApplicationRecord
  has_many :board_game_game_types, dependent: :destroy
  has_many :game_types, through: :board_game_game_types
  has_and_belongs_to_many :game_categories
  has_one :bgg_board_game_association, dependent: :destroy

  # Relations using board_game_relations table
  has_many :outgoing_relations, class_name: 'BoardGameRelation',
           foreign_key: :source_game_id, dependent: :destroy
  has_many :incoming_relations, class_name: 'BoardGameRelation',
           foreign_key: :target_game_id, dependent: :destroy

  # Convenience methods for specific relation types
  has_many :expansions, -> { where(board_game_relations: { relation_type: 'expands' }) },
           through: :incoming_relations, source: :source_game
  has_many :base_games, -> { where(board_game_relations: { relation_type: 'expands' }) },
           through: :outgoing_relations, source: :target_game
  has_many :contained_games, -> { where(board_game_relations: { relation_type: 'contains' }) },
           through: :outgoing_relations, source: :target_game
  has_many :containers, -> { where(board_game_relations: { relation_type: 'contains' }) },
           through: :incoming_relations, source: :source_game

  validates :name, presence: true
  validates :min_players, presence: true, numericality: { greater_than: 0 }
  validates :max_players, presence: true
  validates :max_players, numericality: { greater_than_or_equal_to: :min_players }, if: :min_players
  validates :min_playing_time, numericality: { greater_than: 0 }, allow_nil: true
  validates :max_playing_time, numericality: { greater_than_or_equal_to: :min_playing_time }, allow_nil: true, if: :min_playing_time
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true
  validates :rating_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :difficulty_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  validates :year_published, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :must_have_at_least_one_game_type
  validate :must_have_at_least_one_game_category

  scope :search_by_name, ->(name) { where("name ILIKE ?", "%#{name}%") if name.present? }
  scope :for_player_count, ->(player_count) {
    where("board_games.min_players <= ? AND board_games.max_players >= ?", player_count, player_count) if player_count.present?
  }
  scope :for_playing_time, ->(playing_time) {
    where("board_games.min_playing_time <= ? AND board_games.max_playing_time >= ?", playing_time, playing_time) if playing_time.present?
  }
  scope :max_playing_time_under, ->(max_time) {
    where("board_games.max_playing_time <= ?", max_time) if max_time.present?
  }
  scope :min_playing_time_over, ->(min_time) {
    where("board_games.min_playing_time >= ?", min_time) if min_time.present?
  }
  scope :with_game_types, ->(types) {
    joins(:game_types).where(game_types: { name: types }).distinct if types.present?
  }
  scope :with_min_rating, ->(min_rating) {
    where("board_games.rating >= ?", min_rating) if min_rating.present?
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