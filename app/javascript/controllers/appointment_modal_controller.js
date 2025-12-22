// app/javascript/controllers/appointment_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "title", "form"]

  connect() {
    this.modalTarget.hidden = true
  }

  open(event) {
    event.preventDefault()
    const { appointmentId, appointmentTitle } = event.currentTarget.dataset

    this.titleTarget.textContent = `Decline Appointment: ${appointmentTitle}`
    this.formTarget.action = `/providers/appointments/${appointmentId}/decline`
    this.modalTarget.hidden = false
  }

  close(event) {
    event.preventDefault()
    this.modalTarget.hidden = true
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
