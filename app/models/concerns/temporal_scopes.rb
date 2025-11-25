# app/models/concerns/temporal_scopes.rb
#
# Concern that provides reusable temporal scopes for models with timestamp fields.
# Allows models to easily add scopes like :upcoming, :past, :today without duplicating code.
#
# Usage:
#   class Appointment < ApplicationRecord
#     include TemporalScopes
#     temporal_scope_field :scheduled_at
#   end
#
#   Then you can use:
#     Appointment.upcoming
#     Appointment.past
#     Appointment.today
#     Appointment.between(start_time, end_time)
#
module TemporalScopes
  extend ActiveSupport::Concern

  class_methods do
    # Configure which timestamp field to use for temporal scopes
    # @param field_name [Symbol] the name of the timestamp field (e.g., :scheduled_at, :period_start)
    def temporal_scope_field(field_name)
      # Capture field_name in closure to avoid class instance variable sharing issues
      field = field_name.to_sym
      unless column_names.include?(field.to_s)
        raise ArgumentError, "Invalid temporal scope field: #{field}"
      end

      column = arel_table[field]

      # Scope for records in the future
      scope :upcoming, -> {
        where(column.gteq(Time.current))
          .order(field => :asc)
      }

      # Scope for records in the past
      scope :past, -> {
        where(column.lt(Time.current))
          .order(field => :desc)
      }

      # Scope for records scheduled for today
      scope :today, -> {
        where(field => Time.current.all_day)
      }

      # Scope for records within a specific time range
      # @param start_time [Time, DateTime] start of the range
      # @param end_time [Time, DateTime] end of the range
      scope :between, ->(start_time, end_time) {
        where(field => start_time..end_time)
      }

      # Scope for records on a specific date
      # @param date [Date, Time, DateTime] the date to filter by
      scope :on_date, ->(date) {
        where(field => date.to_date.all_day)
      }
    end
  end
end
