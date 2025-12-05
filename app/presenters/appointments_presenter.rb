# frozen_string_literal: true

# Presenter for displaying appointment collections
# Encapsulates grouping and display logic for appointments
class AppointmentsPresenter
  attr_reader :appointments

  def initialize(appointments)
    @appointments = appointments
  end

  # Group appointments by date
  #
  # @return [Hash] Hash with Date keys and Array<Appointment> values
  def grouped_by_date
    @grouped_by_date ||= appointments.group_by { |appointment| appointment.scheduled_at.to_date }
  end

  # Count of pending appointments
  #
  # @return [Integer] Number of pending appointments
  def pending_count
    appointments.count(&:pending?)
  end

  # Count of confirmed appointments
  #
  # @return [Integer] Number of confirmed appointments
  def confirmed_count
    appointments.count(&:confirmed?)
  end

  # Total count of appointments
  #
  # @return [Integer] Total number of appointments
  def total_count
    appointments.count
  end
end
