module ApplicationHelper
  include TimeFormatHelper

  def user_is_provider?
    user_signed_in? && current_user.provider?
  end

  def user_has_appointments?
    user_signed_in? && current_user.appointments.exists?
  end

  def appointment_status_badge(status)
    colors = {
      "pending" => "bg-yellow-100 text-yellow-800",
      "confirmed" => "bg-green-100 text-green-800",
      "cancelled" => "bg-red-100 text-red-800",
      "completed" => "bg-blue-100 text-blue-800"
    }

    content_tag(:span, status.titleize,
      class: "px-2 py-1 rounded text-sm #{colors[status]}")
  end

  def slot_class(slot)
    base_classes = "border-2"

    case slot.status
    when "available"
      "#{base_classes} bg-green-50 border-green-400 text-green-800"
    when "busy"
      "#{base_classes} bg-red-50 border-red-400 text-red-800"
    else
      "#{base_classes} bg-gray-100 border-gray-300 text-gray-600"
    end
  end
end
