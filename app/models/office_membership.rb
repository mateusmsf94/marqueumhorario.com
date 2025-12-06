class OfficeMembership < ApplicationRecord
  # String length constraints
  MAX_ROLE_LENGTH = 50

  # Associations
  belongs_to :user
  belongs_to :office

  # Validations
  validates :user_id, presence: true
  validates :office_id, presence: true
  validates :role, presence: true, length: { maximum: MAX_ROLE_LENGTH }
  validates :user_id, uniqueness: { scope: :office_id,
    message: "is already a member of this office" }

  # Enums
  enum :role, {
    member: "member",
    admin: "admin",
    owner: "owner"
  }, default: :member, validate: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :for_office, ->(office) { where(office_id: office.id) }
  scope :by_role, ->(role) { where(role: role) }

  # Instance methods
  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end
end
