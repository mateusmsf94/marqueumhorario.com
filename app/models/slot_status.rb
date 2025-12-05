# frozen_string_literal: true

# Constants for slot availability status
# Used by SlotGenerator and related services
module SlotStatus
  # Slot is available for booking
  AVAILABLE = "available"

  # Slot is already booked
  BUSY = "busy"

  # All valid status values
  ALL = [ AVAILABLE, BUSY ].freeze

  # Check if a status value is valid
  #
  # @param status [String] Status to validate
  # @return [Boolean] true if status is valid
  def self.valid?(status)
    ALL.include?(status)
  end
end
