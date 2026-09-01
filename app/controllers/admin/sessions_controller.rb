class Admin::SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to admin_login_url, alert: "Try again later." }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))
    unless user&.admin?
      redirect_to admin_login_path, alert: "Not an operator account. Agents log in from the studio."
      return
    end

    start_new_session_for user
    redirect_to operator_after_login_url
  end

  def destroy
    terminate_session
    redirect_to admin_login_path
  end

  private
    def operator_after_login_url
      target = session.delete(:return_to_after_authenticating).to_s
      return admin_users_path unless target.start_with?("/admin")
      return admin_users_path if target.start_with?("/admin/session") || target == "/admin/login"

      target
    end
end
