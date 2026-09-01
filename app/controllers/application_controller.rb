class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private
    def require_agent!
      return unless Current.user&.admin?

      redirect_to admin_users_path, alert: "That page is for agents. Use Users or Failures."
    end
end
