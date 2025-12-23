# app/mailers/appointment_mailer.rb
class AppointmentMailer < ApplicationMailer
  default from: "notifications@marqueumhorario.com"

  def confirmed(appointment)
    # TODO: Implement confirmed appointment email template
    # Should include: appointment time, office location, and cancellation link
    @appointment = appointment
    mail(to: @appointment.customer.email, subject: "Your Appointment is Confirmed!")
  end

  def declined(appointment)
    # TODO: Implement declined appointment email template
    # Should include: reason for decline and link to reschedule
    @appointment = appointment
    mail(to: @appointment.customer.email, subject: "Your Appointment Has Been Declined")
  end

  def cancelled_by_customer(appointment)
    # TODO: Implement customer cancelled appointment email template
    # Should notify provider that the slot is now free
    @appointment = appointment
    mail(to: @appointment.provider.email, subject: "An Appointment Has Been Cancelled by Customer")
  end
end
