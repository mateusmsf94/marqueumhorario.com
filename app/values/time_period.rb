TimePeriod = Data.define(:start_time, :end_time) do
  def duration
    end_time - start_time
  end

  def overlaps?(other)
    IntervalOverlap.overlaps?(start_time, end_time, other.start_time, other.end_time)
  end

  def contains?(time)
    time >= start_time && time < end_time
  end

  def to_h(timezone: nil)
    if timezone
      {
        start_time: start_time.in_time_zone(timezone).iso8601,
        end_time: end_time.in_time_zone(timezone).iso8601,
        timezone: timezone
      }
    else
      {
        start_time: start_time.iso8601,
        end_time: end_time.iso8601
      }
    end
  end
end
