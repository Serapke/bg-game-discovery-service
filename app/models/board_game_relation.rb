class BoardGameRelation < ApplicationRecord
  belongs_to :source_game, class_name: 'BoardGame', foreign_key: 'source_game_id'
  belongs_to :target_game, class_name: 'BoardGame', foreign_key: 'target_game_id'

  enum :relation_type, {
    expands: 'expands',
    contains: 'contains',
    reimplements: 'reimplements',
    integrates_with: 'integrates_with'
  }, validate: true

  validates :relation_type, presence: true
  validates :source_game_id, uniqueness: { scope: [:target_game_id, :relation_type] }
  validate :cannot_relate_to_self

  private

  def cannot_relate_to_self
    errors.add(:target_game_id, "cannot relate to itself") if source_game_id == target_game_id
  end
end
