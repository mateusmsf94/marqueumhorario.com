# User account model supporting both providers and customers
#
# Handles user authentication and role-based functionality:
# - Provider users can manage offices, schedules, and appointments
# - Customer users can book and track appointments
# - Role-based authorization via Pundit policies
class User < ApplicationRecord
  # String length constraints
  MAX_NAME_LENGTH = 100
  MAX_PHONE_LENGTH = 20
  CPF_LENGTH = 11  # Brazilian CPF format: XXX.XXX.XXX-XX (11 digits)

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

  # Validations
  validates :first_name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :last_name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :phone, length: { maximum: MAX_PHONE_LENGTH }, allow_blank: true
  validates :cpf, length: { is: CPF_LENGTH }, allow_blank: true, uniqueness: { case_sensitive: false }
  validate :cpf_format_validation, if: :cpf?

  # Scopes
  scope :with_cpf, -> { where.not(cpf: nil) }

  # Virtual attributes
  # Override cpf setter to normalize input (strip non-digit characters)
  def cpf=(value)
    super(value&.gsub(/\D/, ""))
  end

  # Format CPF for display (XXX.XXX.XXX-XX)
  def cpf_formatted
    return unless cpf
    cpf.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4')
  end

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  # Check if user is a provider (manages at least one office)
  #
  # @return [Boolean] true if user has at least one office
  def provider?
    offices.exists?
  end

  # Manage offices
  def manages_office?(office)
    return false unless office
    offices.exists?(office.id)
  end

  def add_office(office)
    return false unless office&.persisted?
    return true if manages_office?(office)
    offices << office
    true
  end

  def remove_office(office)
    return false unless office
    offices.delete(office)
    true
  end

  private

  def cpf_format_validation
    return if cpf.blank?

    # Check for known invalid CPFs (all same digit)
    if cpf.match?(/\A(\d)\1{10}\z/)
      errors.add(:cpf, "is invalid")
    end
  end
end
