class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :first_name, :last_name, :phone, :cpf, :user_type
    ])
    devise_parameter_sanitizer.permit(:account_update, keys: [
      :first_name, :last_name, :phone
    ])
  end

  def authenticate_provider!
    authenticate_user!
    unless current_user.provider?
      redirect_to root_path, alert: "Access denied. Provider account required."
    end
  end

  def authenticate_customer!
    authenticate_user!
    unless current_user.customer?
      redirect_to root_path, alert: "Access denied. Customer account required."
    end
  end
end
