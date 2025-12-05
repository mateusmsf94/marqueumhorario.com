require "test_helper"

class SlotStatusTest < ActiveSupport::TestCase
  test "defines AVAILABLE constant" do
    assert_equal "available", SlotStatus::AVAILABLE
  end

  test "defines BUSY constant" do
    assert_equal "busy", SlotStatus::BUSY
  end

  test "ALL contains all valid statuses" do
    assert_equal ["available", "busy"], SlotStatus::ALL
  end

  test "valid? returns true for AVAILABLE" do
    assert SlotStatus.valid?(SlotStatus::AVAILABLE)
  end

  test "valid? returns true for BUSY" do
    assert SlotStatus.valid?(SlotStatus::BUSY)
  end

  test "valid? returns false for invalid status" do
    refute SlotStatus.valid?("invalid")
    refute SlotStatus.valid?("pending")
    refute SlotStatus.valid?(nil)
  end
end
