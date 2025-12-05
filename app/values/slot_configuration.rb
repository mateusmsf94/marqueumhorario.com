# frozen_string_literal: true

# Value object that encapsulates slot configuration for appointment generation
# Bundles duration, buffer time, and work periods together
SlotConfiguration = Data.define(:duration, :buffer, :periods) do
  # Total duration of a slot including buffer time
  # @return [ActiveSupport::Duration] total duration in seconds
  def total_slot_duration
    duration + buffer
  end
end
