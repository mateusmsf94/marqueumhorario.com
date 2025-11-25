# app/validators/time_range_validator.rb
#
# Custom validator for ensuring that a time range is valid (end time after start time).
# This validator can be reused across multiple models that have time range fields.
#
# Usage:
#   validates_with TimeRangeValidator, start: :opening_time, end: :closing_time
#
class TimeRangeValidator < ActiveModel::Validator
  def validate(record)
    start_field = options[:start]
    end_field = options[:end]

    unless start_field && end_field
      raise ArgumentError, "TimeRangeValidator requires both :start and :end options"
    end

    start_time = record.send(start_field)
    end_time = record.send(end_field)

    # Only validate if both times are present
    return unless start_time && end_time

    if start_time >= end_time
      record.errors.add(end_field, "must be after #{start_field.to_s.humanize.downcase}")
    end
  end
end
