// app/javascript/controllers/appointment_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "title", "form"]

  connect() {
    // Modal starts hidden via CSS class
  }

  open(event) {
    event.preventDefault()
    const { appointmentId, appointmentTitle } = event.currentTarget.dataset

    this.titleTarget.textContent = `Decline Appointment: ${appointmentTitle}`
    this.formTarget.action = `/providers/appointments/${appointmentId}/decline`
    this.modalTarget.classList.remove("hidden")
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add("hidden")
    this.formTarget.reset() // Reset form fields on close
  }

  // Close modal when clicking outside of it
  // This assumes the modal overlay has a click event that bubbles up
  hideModal(event) {
    if (event.target === this.modalTarget) {
      this.close(event)
    }
  }
}
