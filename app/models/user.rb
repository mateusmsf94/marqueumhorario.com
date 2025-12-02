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

  # Callbacks
  before_validation :normalize_cpf

  # Validations
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :phone, length: { maximum: 20 }, allow_blank: true
  validates :cpf, length: { is: 11 }, allow_blank: true, uniqueness: { case_sensitive: false }
  validate :cpf_format_validation, if: :cpf?

  # Scopes
  scope :with_cpf, -> { where.not(cpf: nil) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  # Manage offices
  def manages_office?(office)
    offices.exists?(office.id)
  end

  def add_office(office)
    offices << office unless manages_office?(office)
  end

  def remove_office(office)
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
end
