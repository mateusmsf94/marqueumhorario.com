# app/controllers/providers/appointments_controller.rb
module Providers
  class AppointmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_appointment, only: %i[confirm decline cancel]

    def confirm
      if @appointment.cancelled?
        redirect_to providers_dashboard_path, alert: "Appointment is already cancelled."
        return
      end

      @appointment.lock_version = params[:lock_version] if params[:lock_version]

      begin
        if @appointment.confirmed!
          # TODO: Send confirmation notification
          redirect_to providers_dashboard_path, notice: "Appointment confirmed successfully."
        else
          redirect_to providers_dashboard_path, alert: "Failed to confirm appointment: #{@appointment.errors.full_messages.to_sentence}"
        end
      rescue ActiveRecord::StaleObjectError
        redirect_to providers_dashboard_path, alert: "This appointment was modified by another user. Please review and try again."
      end
    end

    def decline
      unless decline_reason_present?
        redirect_to providers_dashboard_path, alert: "Decline reason is required."
        return
      end

      if @appointment.update(
        status: :cancelled,
        declined_at: Time.current,
        decline_reason: params[:appointment][:decline_reason],
        confirmed_at: nil
      )
        # TODO: Send declined notification
        redirect_to providers_dashboard_path, notice: "Appointment declined successfully."
      else
        redirect_to providers_dashboard_path, alert: "Failed to decline appointment: #{@appointment.errors.full_messages.to_sentence}"
      end
    end

    def cancel
      if @appointment.cancelled!
        # TODO: Send cancellation notification
        redirect_to providers_dashboard_path, notice: "Appointment cancelled successfully."
      else
        redirect_to providers_dashboard_path, alert: "Failed to cancel appointment: #{@appointment.errors.full_messages.to_sentence}"
      end
    end

    private

    def set_appointment
      @appointment = current_user.provider_appointments.find(params[:id])
    end

    def decline_reason_present?
      params[:appointment].present? && params[:appointment][:decline_reason].present?
    end
  end
end
