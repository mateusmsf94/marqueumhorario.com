import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for interactive week grid.
 *
 * Handles:
 * - Clicking on day headers to edit that day's schedule
 * - Visual feedback on hover
 *
 * Targets: None
 * Values:
 *   - officeId: The office ID (passed via data attribute)
 * Actions:
 *   - editDay: Navigate to edit page for specific day
 */
export default class extends Controller {
  static values = {
    officeId: String
  }

  /**
   * Navigate to edit schedule page when day is clicked
   * Includes URL fragment to auto-scroll/focus on that day
   *
   * @param {Event} event - Click event from day header
   */
  editDay(event) {
    const dayOfWeek = event.params.day // e.g., "monday"
    const officeId = event.params.officeId

    // Construct edit URL with day fragment
    // This allows the edit page to scroll to or highlight the clicked day
    const editUrl = `/providers/offices/${officeId}/work_schedules/edit#day-${dayOfWeek}`

    // Navigate with Turbo for smooth page transition
    Turbo.visit(editUrl)
  }

  /**
   * Optional: Add visual feedback when hovering over days
   * This could highlight all slots for that day
   */
  highlightDay(event) {
    // Future enhancement: highlight all slots for this day
    console.log("Highlighting day:", event.params.day)
  }

  /**
   * Optional: Remove highlight when mouse leaves
   */
  unhighlightDay(event) {
    // Future enhancement: remove highlight
    console.log("Unhighlighting day:", event.params.day)
  }
}

