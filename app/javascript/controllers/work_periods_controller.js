import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for managing dynamic work period fields.
 *
 * Handles:
 * - Toggling day visibility when checkbox changes
 * - Adding new work period time inputs
 * - Removing work periods (enforces min 1, max 4)
 * - Re-indexing field names to maintain proper Rails array params
 *
 * Targets:
 *   - container: The div holding all work period inputs
 *   - period: Individual work period divs
 *   - inputs: The section to show/hide when day is toggled
 *
 * Values:
 *   - day: The day of week number (0-6)
 *   - maxPeriods: Maximum periods allowed (default: 4)
 */
export default class extends Controller {
  static targets = ["container", "period", "inputs"]
  static values = {
    day: Number,
    maxPeriods: { type: Number, default: 4 }
  }

  /**
   * Initialize the controller
   * Count existing periods on page load
   */
  connect() {
    this.periodCount = this.periodTargets.length
    console.log(`Work periods controller connected for day ${this.dayValue}. Current periods: ${this.periodCount}`)
  }

  /**
   * Toggle visibility of day inputs when checkbox changes
   *
   * @param {Event} event - The change event from the checkbox
   */
  toggleDay(event) {
    const isOpen = event.target.checked
    this.inputsTarget.style.display = isOpen ? 'block' : 'none'

    console.log(`Day ${this.dayValue} toggled ${isOpen ? 'on' : 'off'}`)
  }

  /**
   * Add a new work period to the day
   * Enforces maximum periods limit
   *
   * @param {Event} event - The click event from "Add period" button
   */
  addPeriod(event) {
    event.preventDefault()

    // Enforce maximum periods limit
    if (this.periodCount >= this.maxPeriodsValue) {
      alert(`Maximum ${this.maxPeriodsValue} time periods allowed per day`)
      return
    }

    // Create and insert new period HTML
    const template = this.createPeriodTemplate(this.periodCount)
    this.containerTarget.insertAdjacentHTML('beforeend', template)
    this.periodCount++

    console.log(`Added period. Day ${this.dayValue} now has ${this.periodCount} periods`)
  }

  /**
   * Remove a work period from the day
   * Enforces minimum 1 period when day is open
   *
   * @param {Event} event - The click event from "Remove" button
   */
  removePeriod(event) {
    event.preventDefault()

    // Enforce minimum 1 period
    if (this.periodCount <= 1) {
      alert("Must have at least one time period when day is open")
      return
    }

    // Remove the period div
    const periodElement = event.target.closest('[data-work-periods-target="period"]')
    periodElement.remove()
    this.periodCount--

    // Re-index remaining periods to maintain sequential array indices
    this.reindexPeriods()

    console.log(`Removed period. Day ${this.dayValue} now has ${this.periodCount} periods`)
  }

  /**
   * Create HTML template for a new work period
   * Maintains proper Rails array parameter naming
   *
   * @param {number} index - The index for this period (0-based)
   * @returns {string} HTML string for the new period
   */
  createPeriodTemplate(index) {
    const day = this.dayValue

    return `
      <div class="work-period flex items-center gap-3 p-3 bg-gray-50 rounded-md"
           data-work-periods-target="period">

        <div class="flex-1 flex items-center gap-3">
          <div class="flex-1">
            <input type="time"
                   name="schedules[${day}][work_periods][${index}][start]"
                   value="09:00"
                   step="900"
                   class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
          </div>

          <span class="text-gray-500 font-medium">to</span>

          <div class="flex-1">
            <input type="time"
                   name="schedules[${day}][work_periods][${index}][end]"
                   value="17:00"
                   step="900"
                   class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
          </div>
        </div>

        <button type="button"
                data-action="work-periods#removePeriod"
                class="flex-shrink-0 text-red-600 hover:text-red-800 text-sm font-medium px-3 py-2 hover:bg-red-50 rounded-md transition-colors">
          Remove
        </button>
      </div>
    `
  }

  /**
   * Re-index all period field names to maintain sequential array indices
   * This ensures Rails receives proper params after periods are removed
   *
   * Example: If period 1 is removed from [0, 1, 2], this updates indices to [0, 1]
   * so Rails doesn't receive params with gaps like [0, 2]
   */
  reindexPeriods() {
    this.periodTargets.forEach((periodElement, index) => {
      // Find the time input fields within this period
      const timeInputs = periodElement.querySelectorAll('input[type="time"]')

      // Update the 'name' attribute to reflect new index
      // timeInputs[0] is start time, timeInputs[1] is end time
      if (timeInputs[0]) {
        timeInputs[0].name = `schedules[${this.dayValue}][work_periods][${index}][start]`
      }
      if (timeInputs[1]) {
        timeInputs[1].name = `schedules[${this.dayValue}][work_periods][${index}][end]`
      }
    })

    console.log(`Re-indexed ${this.periodTargets.length} periods for day ${this.dayValue}`)
  }
}
