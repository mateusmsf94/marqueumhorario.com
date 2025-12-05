class WorkPeriodValidator < ActiveModel::Validator
  def validate(record)
    # The attribute to validate is passed via options, defaulting to :work_periods
    attribute = options[:attribute] || :work_periods
    periods = record.send(attribute)

    return if periods.blank?

    # Validate format of each period
    periods.each_with_index do |period, i|
      unless valid_time_format?(period["start"]) && valid_time_format?(period["end"])
        record.errors.add(attribute, "period #{i + 1} has invalid time format (must be HH:MM)")
        next # Skip further checks for this malformed period
      end

      if time_in_minutes(period["start"]) >= time_in_minutes(period["end"])
        record.errors.add(attribute, "period #{i + 1} end time must be after start time")
      end
    end

    # Return if any format errors were found, as overlap check would be unreliable
    return if record.errors.key?(attribute)

    # Validate overlaps between periods
    periods.combination(2).each do |p1, p2|
      if periods_overlap?(p1, p2)
        record.errors.add(attribute, "periods #{p1['start']}-#{p1['end']} and #{p2['start']}-#{p2['end']} overlap")
      end
    end
  end

  private

  def valid_time_format?(time_str)
    time_str.is_a?(String) && TimeParsing.valid_time_format?(time_str)
  end

  def time_in_minutes(time_str)
    TimeParsing.parse_time_to_minutes(time_str)
  end

  def periods_overlap?(p1, p2)
    start1 = time_in_minutes(p1["start"])
    end1 = time_in_minutes(p1["end"])
    start2 = time_in_minutes(p2["start"])
    end2 = time_in_minutes(p2["end"])

    # Overlap exists if one period starts before the other one ends
    start1 < end2 && start2 < end1
  end
end
