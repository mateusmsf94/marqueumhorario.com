import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

// Stimulus controller for Flatpickr 24-hour time picker
// Automatically initializes on connect, cleans up on disconnect
export default class extends Controller {
  static values = {
    default: { type: String, default: "09:00" }
  }

  connect() {
    // Initialize Flatpickr with 24-hour format
    this.picker = flatpickr(this.element, {
      enableTime: true,       // Enable time picker
      noCalendar: true,       // Hide calendar, show only time
      dateFormat: "H:i",      // 24-hour format HH:MM
      time_24hr: true,        // CRITICAL: Force 24-hour format
      minuteIncrement: 1,     // 1-minute intervals for precise scheduling
      defaultDate: this.defaultValue,
      inline: true,           // Display picker inline (always visible)
      allowInput: false,      // Disable typing (only picker interaction)

      // Update input value on change for Rails form submission
      onChange: (_selectedDates, dateStr) => {
        this.element.value = dateStr
        this.element.dispatchEvent(new Event('time-picker:change', { bubbles: true }))
      }
    })

    console.log(`Time picker initialized: ${this.element.name}`)
  }

  disconnect() {
    // Cleanup when element removed (prevents memory leaks)
    if (this.picker) {
      this.picker.destroy()
      console.log(`Time picker destroyed: ${this.element.name}`)
    }
  }
}
