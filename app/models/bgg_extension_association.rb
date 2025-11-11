class BggExtensionAssociation < ApplicationRecord
  belongs_to :extension

  validates :bgg_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :bgg_id, uniqueness: true
  validates :extension_id, uniqueness: { scope: :bgg_id }
end