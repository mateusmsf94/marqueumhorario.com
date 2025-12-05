# frozen_string_literal: true

require "test_helper"

class IntervalOverlapTest < ActiveSupport::TestCase
  # Basic overlap detection tests
  test "detects overlap when intervals intersect in the middle" do
    # 9:00-12:00 overlaps with 11:00-14:00
    assert IntervalOverlap.overlaps?(9, 12, 11, 14),
           "Intervals should overlap when second starts before first ends"
  end

  test "detects overlap when first interval contains second" do
    # 9:00-17:00 contains 10:00-12:00
    assert IntervalOverlap.overlaps?(9, 17, 10, 12),
           "Intervals should overlap when one contains the other"
  end

  test "detects overlap when second interval contains first" do
    # 10:00-12:00 is contained in 9:00-17:00
    assert IntervalOverlap.overlaps?(10, 12, 9, 17),
           "Intervals should overlap when inner is contained in outer"
  end

  test "detects overlap when intervals start at same time" do
    # 9:00-12:00 and 9:00-14:00
    assert IntervalOverlap.overlaps?(9, 12, 9, 14),
           "Intervals with same start time should overlap"
  end

  test "detects overlap when intervals end at same time" do
    # 9:00-12:00 and 10:00-12:00
    assert IntervalOverlap.overlaps?(9, 12, 10, 12),
           "Intervals with same end time should overlap"
  end

  test "detects overlap when intervals are identical" do
    # 9:00-12:00 and 9:00-12:00
    assert IntervalOverlap.overlaps?(9, 12, 9, 12),
           "Identical intervals should overlap"
  end

  # Non-overlap tests
  test "detects no overlap when intervals are completely separate" do
    # 9:00-12:00 and 13:00-15:00
    refute IntervalOverlap.overlaps?(9, 12, 13, 15),
           "Separate intervals should not overlap"
  end

  test "detects no overlap when intervals are adjacent (touching)" do
    # 9:00-12:00 and 12:00-15:00 (adjacent but not overlapping)
    refute IntervalOverlap.overlaps?(9, 12, 12, 15),
           "Adjacent intervals should not overlap"
  end

  test "detects no overlap when second interval is before first" do
    # 13:00-15:00 and 9:00-12:00
    refute IntervalOverlap.overlaps?(13, 15, 9, 12),
           "Intervals should not overlap when second is before first"
  end

  # Edge cases with Time objects
  test "works with Time objects" do
    t1 = Time.zone.parse("2025-01-01 09:00")
    t2 = Time.zone.parse("2025-01-01 12:00")
    t3 = Time.zone.parse("2025-01-01 11:00")
    t4 = Time.zone.parse("2025-01-01 14:00")

    assert IntervalOverlap.overlaps?(t1, t2, t3, t4),
           "Should work with Time objects"
  end

  test "works with DateTime objects" do
    dt1 = DateTime.parse("2025-01-01 09:00")
    dt2 = DateTime.parse("2025-01-01 12:00")
    dt3 = DateTime.parse("2025-01-01 11:00")
    dt4 = DateTime.parse("2025-01-01 14:00")

    assert IntervalOverlap.overlaps?(dt1, dt2, dt3, dt4),
           "Should work with DateTime objects"
  end

  test "works with Float values" do
    assert IntervalOverlap.overlaps?(9.5, 12.5, 11.0, 14.0),
           "Should work with Float values"
  end

  # Boundary precision tests
  test "correctly handles very close but non-overlapping intervals" do
    # Using precise timestamps to ensure no rounding issues
    t1_end = Time.zone.parse("2025-01-01 12:00:00")
    t2_start = Time.zone.parse("2025-01-01 12:00:00")

    refute IntervalOverlap.overlaps?(
      Time.zone.parse("2025-01-01 09:00:00"),
      t1_end,
      t2_start,
      Time.zone.parse("2025-01-01 15:00:00")
    ), "Should not overlap when end equals start"
  end

  test "correctly handles minimal overlap of 1 second" do
    t1 = Time.zone.parse("2025-01-01 09:00:00")
    t2 = Time.zone.parse("2025-01-01 12:00:01")
    t3 = Time.zone.parse("2025-01-01 12:00:00")
    t4 = Time.zone.parse("2025-01-01 15:00:00")

    assert IntervalOverlap.overlaps?(t1, t2, t3, t4),
           "Should overlap with even 1 second overlap"
  end

  # Tests for contains? method
  test "contains? returns true when inner interval is completely contained" do
    # 9:00-17:00 contains 10:00-12:00
    assert IntervalOverlap.contains?(9, 17, 10, 12),
           "Should detect containment"
  end

  test "contains? returns true when intervals are identical" do
    # 9:00-17:00 contains 9:00-17:00
    assert IntervalOverlap.contains?(9, 17, 9, 17),
           "Identical intervals should be contained"
  end

  test "contains? returns true when inner starts at outer start" do
    # 9:00-17:00 contains 9:00-12:00
    assert IntervalOverlap.contains?(9, 17, 9, 12),
           "Should contain when starts align"
  end

  test "contains? returns true when inner ends at outer end" do
    # 9:00-17:00 contains 12:00-17:00
    assert IntervalOverlap.contains?(9, 17, 12, 17),
           "Should contain when ends align"
  end

  test "contains? returns false when inner starts before outer" do
    # 9:00-17:00 does not contain 8:00-12:00
    refute IntervalOverlap.contains?(9, 17, 8, 12),
           "Should not contain when inner starts before outer"
  end

  test "contains? returns false when inner ends after outer" do
    # 9:00-17:00 does not contain 12:00-18:00
    refute IntervalOverlap.contains?(9, 17, 12, 18),
           "Should not contain when inner ends after outer"
  end

  test "contains? returns false when inner is completely outside" do
    # 9:00-17:00 does not contain 18:00-20:00
    refute IntervalOverlap.contains?(9, 17, 18, 20),
           "Should not contain when inner is completely outside"
  end

  test "contains? works with Time objects" do
    outer_start = Time.zone.parse("2025-01-01 09:00")
    outer_end = Time.zone.parse("2025-01-01 17:00")
    inner_start = Time.zone.parse("2025-01-01 10:00")
    inner_end = Time.zone.parse("2025-01-01 12:00")

    assert IntervalOverlap.contains?(outer_start, outer_end, inner_start, inner_end),
           "Should work with Time objects"
  end

  # Realistic use case tests
  test "handles appointment overlap scenario" do
    # Appointment at 10:00 with 60 min duration vs slot at 10:30-11:30
    apt_start = Time.zone.parse("2025-01-01 10:00")
    apt_end = apt_start + 60.minutes
    slot_start = Time.zone.parse("2025-01-01 10:30")
    slot_end = slot_start + 60.minutes

    assert IntervalOverlap.overlaps?(apt_start, apt_end, slot_start, slot_end),
           "Should detect appointment overlap with slot"
  end

  test "handles work period overlap scenario" do
    # Work periods: 9:00-12:00 and 11:00-15:00 (should overlap)
    period1_start = 9 * 60  # 540 minutes (9:00)
    period1_end = 12 * 60   # 720 minutes (12:00)
    period2_start = 11 * 60 # 660 minutes (11:00)
    period2_end = 15 * 60   # 900 minutes (15:00)

    assert IntervalOverlap.overlaps?(
      period1_start, period1_end, period2_start, period2_end
    ), "Should detect work period overlap"
  end

  test "handles non-overlapping work periods" do
    # Work periods: 9:00-12:00 and 13:00-17:00 (lunch break in between)
    morning_start = 9 * 60
    morning_end = 12 * 60
    afternoon_start = 13 * 60
    afternoon_end = 17 * 60

    refute IntervalOverlap.overlaps?(
      morning_start, morning_end, afternoon_start, afternoon_end
    ), "Should not detect overlap with lunch break"
  end

  # Symmetry tests
  test "overlaps? is symmetric (order doesn't matter)" do
    # If interval1 overlaps interval2, then interval2 overlaps interval1
    assert_equal(
      IntervalOverlap.overlaps?(9, 12, 11, 14),
      IntervalOverlap.overlaps?(11, 14, 9, 12),
      "Overlap detection should be symmetric"
    )
  end

  test "overlaps? symmetry holds for non-overlapping intervals" do
    assert_equal(
      IntervalOverlap.overlaps?(9, 12, 13, 15),
      IntervalOverlap.overlaps?(13, 15, 9, 12),
      "Non-overlap should also be symmetric"
    )
  end
end
