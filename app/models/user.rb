class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  # Associations
  has_many :office_memberships, dependent: :destroy
  has_many :offices, through: :office_memberships

  # For customers - appointments they booked
  has_many :appointments, foreign_key: :customer_id, dependent: :restrict_with_error

  # For providers - appointments they're assigned to
  has_many :provider_appointments, class_name: "Appointment", foreign_key: :provider_id, dependent: :restrict_with_error

  # For providers - work schedules
  has_many :work_schedules, foreign_key: :provider_id, dependent: :destroy

  # Available roles
  AVAILABLE_ROLES = %w[customer provider].freeze

  # Callbacks
  before_validation :normalize_cpf

  # Validations
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :phone, length: { maximum: 20 }, allow_blank: true
  validates :cpf, length: { is: 11 }, allow_blank: true, uniqueness: { case_sensitive: false }
  validates :roles, presence: true
  validate :cpf_format_validation, if: :cpf?
  validate :roles_are_valid

  # Scopes
  scope :providers, -> { where("'provider' = ANY(roles)") }
  scope :customers, -> { where("'customer' = ANY(roles)") }
  scope :with_cpf, -> { where.not(cpf: nil) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def provider?
    roles.include?("provider")
  end

  def customer?
    roles.include?("customer")
  end

  def has_role?(role)
    roles.include?(role.to_s)
  end

  def add_role(role)
    role = role.to_s
    return false unless AVAILABLE_ROLES.include?(role)
    return true if has_role?(role)

    self.roles = (roles + [ role ]).uniq
    save
  end

  def remove_role(role)
    role = role.to_s
    return false unless has_role?(role)

    self.roles = roles - [ role ]
    save
  end

  # Manage offices (for providers)
  def manages_office?(office)
    return false unless provider?
    offices.exists?(office.id)
  end

  def add_office(office)
    return false unless provider?
    offices << office unless manages_office?(office)
  end

  def remove_office(office)
    return false unless provider?
    offices.delete(office)
  end

  private

  def normalize_cpf
    return if cpf.blank?
    # Remove any non-digit characters
    self.cpf = cpf.gsub(/\D/, "")
  end

  def cpf_format_validation
    return if cpf.blank?

    # Check for known invalid CPFs (all same digit)
    if cpf.match?(/\A(\d)\1{10}\z/)
      errors.add(:cpf, "is invalid")
    end
  end

  def roles_are_valid
    return if roles.blank?

    invalid_roles = roles - AVAILABLE_ROLES
    if invalid_roles.any?
      errors.add(:roles, "contains invalid role(s): #{invalid_roles.join(', ')}")
    end
  end
end
