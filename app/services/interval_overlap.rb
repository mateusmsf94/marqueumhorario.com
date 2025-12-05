# frozen_string_literal: true

# app/services/interval_overlap.rb
#
# Module providing interval overlap detection algorithms.
# Centralizes overlap logic that was previously duplicated across multiple classes.
#
# This module provides a single source of truth for interval operations,
# making the codebase more maintainable and reducing the risk of divergent implementations.
#
# Usage:
#   IntervalOverlap.overlaps?(9, 12, 11, 14)  # => true
#   IntervalOverlap.overlaps?(9, 12, 13, 14)  # => false
#   IntervalOverlap.contains?(9, 17, 10, 12)  # => true
#
module IntervalOverlap
  # Checks if two intervals overlap
  #
  # Two intervals overlap if they share any common point in time.
  # Uses the standard interval overlap algorithm: start1 < end2 AND start2 < end1
  #
  # This works because:
  # - If interval1 starts before interval2 ends (start1 < end2), AND
  # - If interval2 starts before interval1 ends (start2 < end1)
  # Then they must overlap
  #
  # Edge cases:
  # - Adjacent intervals (end1 == start2) do NOT overlap
  # - Intervals with the same start or end time DO overlap (unless they're identical points)
  # - Works with any comparable types (Time, DateTime, Integer, etc.)
  #
  # @param start1 [Time, DateTime, Numeric] Start of first interval
  # @param end1 [Time, DateTime, Numeric] End of first interval
  # @param start2 [Time, DateTime, Numeric] Start of second interval
  # @param end2 [Time, DateTime, Numeric] End of second interval
  # @return [Boolean] true if intervals overlap, false otherwise
  #
  # @example Time objects
  #   t1 = Time.zone.parse("2025-01-01 09:00")
  #   t2 = Time.zone.parse("2025-01-01 12:00")
  #   t3 = Time.zone.parse("2025-01-01 11:00")
  #   t4 = Time.zone.parse("2025-01-01 14:00")
  #   IntervalOverlap.overlaps?(t1, t2, t3, t4)  # => true (11:00-12:00 overlaps)
  #
  # @example Minutes since midnight
  #   IntervalOverlap.overlaps?(540, 720, 660, 840)  # => true (9:00-12:00 overlaps with 11:00-14:00)
  #
  # @example Adjacent intervals (no overlap)
  #   IntervalOverlap.overlaps?(9, 12, 12, 15)  # => false
  #
  def self.overlaps?(start1, end1, start2, end2)
    start1 < end2 && start2 < end1
  end

  # Checks if one interval is completely contained within another
  #
  # An interval is contained if it starts at or after the outer interval's start
  # and ends at or before the outer interval's end.
  #
  # @param outer_start [Time, DateTime, Numeric] Start of containing interval
  # @param outer_end [Time, DateTime, Numeric] End of containing interval
  # @param inner_start [Time, DateTime, Numeric] Start of contained interval
  # @param inner_end [Time, DateTime, Numeric] End of contained interval
  # @return [Boolean] true if inner interval is completely contained within outer interval
  #
  # @example
  #   IntervalOverlap.contains?(9, 17, 10, 12)  # => true (10-12 is within 9-17)
  #   IntervalOverlap.contains?(9, 17, 8, 12)   # => false (starts before outer)
  #   IntervalOverlap.contains?(9, 17, 10, 18)  # => false (ends after outer)
  #
  def self.contains?(outer_start, outer_end, inner_start, inner_end)
    outer_start <= inner_start && inner_end <= outer_end
  end
end
