class Admin::BaseController < ApplicationController
  skip_before_action :require_authentication
  before_action :require_operator

  private
    def require_operator
      unless resume_session
        session[:return_to_after_authenticating] = request.fullpath
        redirect_to admin_login_path
        return
      end

      return if Current.user.admin?

      redirect_to listings_path, alert: "Admin only."
    end
end
