class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Require authentication for all actions (Devise)
  before_action :authenticate_user!

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :first_name, :last_name, :phone, :cpf
    ])
    devise_parameter_sanitizer.permit(:account_update, keys: [
      :first_name, :last_name, :phone, :avatar, :slug, :bio
    ])
  end

  def after_sign_in_path_for(resource)
    # Check for booking intent stored before authentication
    if session[:booking_intent].present?
      intent = session.delete(:booking_intent)
      return new_booking_path(
        intent["provider_slug"],
        office_id: intent["office_id"],
        slot_start: intent["slot_start"],
        slot_end: intent["slot_end"]
      )
    end

    # Default: redirect to customer appointments page
    customers_appointments_path
  end
end
