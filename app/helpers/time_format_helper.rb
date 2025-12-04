# frozen_string_literal: true

module TimeFormatHelper
  # Format time in 24-hour format (HH:mm)
  # @param time [Time, DateTime, ActiveSupport::TimeWithZone]
  # @param timezone [String] optional timezone (defaults to UTC)
  # @return [String] formatted time like "09:00"
  def format_time_24h(time, timezone: nil)
    return "" unless time

    time_in_zone = timezone ? time.in_time_zone(timezone) : time
    time_in_zone.strftime("%H:%M")
  end

  # Format date and time (YYYY-MM-DD HH:mm)
  # @param time [Time, DateTime, ActiveSupport::TimeWithZone]
  # @param timezone [String] optional timezone
  # @return [String] formatted datetime like "2025-01-15 09:00"
  def format_datetime_24h(time, timezone: nil)
    return "" unless time

    time_in_zone = timezone ? time.in_time_zone(timezone) : time
    time_in_zone.strftime("%Y-%m-%d %H:%M")
  end

  # Format full datetime with day name (Day, DD MMM YYYY HH:mm)
  # @param time [Time, DateTime, ActiveSupport::TimeWithZone]
  # @param timezone [String] optional timezone
  # @return [String] formatted datetime like "Mon, 15 Jan 2025 09:00"
  def format_full_datetime_24h(time, timezone: nil)
    return "" unless time

    time_in_zone = timezone ? time.in_time_zone(timezone) : time
    time_in_zone.strftime("%a, %d %b %Y %H:%M")
  end

  # Format date only (YYYY-MM-DD)
  # @param date [Date, Time, DateTime]
  # @return [String] formatted date like "2025-01-15"
  def format_date_iso(date)
    return "" unless date

    date.to_date.strftime("%Y-%m-%d")
  end

  # Format date with month name (DD MMM YYYY)
  # @param date [Date, Time, DateTime]
  # @return [String] formatted date like "15 Jan 2025"
  def format_date_verbose(date)
    return "" unless date

    date.to_date.strftime("%d %b %Y")
  end

  # Format time with timezone abbreviation (HH:mm TZ)
  # @param time [Time, DateTime, ActiveSupport::TimeWithZone]
  # @param timezone [String] required timezone
  # @return [String] formatted time like "09:00 PST"
  def format_time_with_zone(time, timezone:)
    return "" unless time

    time_in_zone = time.in_time_zone(timezone)
    "#{time_in_zone.strftime('%H:%M')} #{time_in_zone.zone}"
  end

  # Format appointment time for customer display
  # Combines date and time with office timezone
  # @param appointment [Appointment]
  # @return [String] formatted like "2025-01-15 09:00"
  def format_appointment_time(appointment)
    return "" unless appointment&.scheduled_at

    format_datetime_24h(
      appointment.scheduled_at,
      timezone: appointment.office&.time_zone
    )
  end

  # Format appointment time with timezone
  # @param appointment [Appointment]
  # @return [String] formatted like "2025-01-15 09:00 PST"
  def format_appointment_time_with_zone(appointment)
    return "" unless appointment&.scheduled_at && appointment.office

    time_in_zone = appointment.scheduled_at.in_time_zone(appointment.office.time_zone)
    "#{time_in_zone.strftime('%Y-%m-%d %H:%M')} #{time_in_zone.zone}"
  end

  # Format duration in minutes to hours and minutes
  # @param minutes [Integer] duration in minutes
  # @return [String] formatted like "1h 30m" or "45m"
  def format_duration(minutes)
    return "" unless minutes

    hours = minutes / 60
    mins = minutes % 60

    if hours > 0 && mins > 0
      "#{hours}h #{mins}m"
    elsif hours > 0
      "#{hours}h"
    else
      "#{mins}m"
    end
  end

  # Format time range (HH:mm - HH:mm)
  # @param start_time [Time]
  # @param end_time [Time]
  # @param timezone [String] optional timezone
  # @return [String] formatted like "09:00 - 17:00"
  def format_time_range(start_time, end_time, timezone: nil)
    return "" unless start_time && end_time

    start_formatted = format_time_24h(start_time, timezone: timezone)
    end_formatted = format_time_24h(end_time, timezone: timezone)

    "#{start_formatted} - #{end_formatted}"
  end

  # Convert minutes to time format (HH:MM)
  # @param minutes [Integer] number of minutes
  # @return [String] formatted time like "00:50" or "01:30"
  def format_minutes_as_time(minutes)
    return "00:00" unless minutes

    hours = minutes / 60
    mins = minutes % 60

    format("%02d:%02d", hours, mins)
  end
end
