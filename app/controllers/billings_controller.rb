class BillingsController < ApplicationController
  def show
    Current.user.reset_quota_if_needed!

    if params[:paid].present?
      flash.now[:notice] = "Payment received. Pro unlocks as soon as PayMongo confirms the webhook — refresh in a moment if your plan still says Free."
    elsif params[:canceled].present?
      flash.now[:alert] = "Checkout canceled. You are still on Free."
    end
  end

  def update
    if Billing::Paymongo.configured?
      session = Billing::Checkout.new(user: Current.user).call
      redirect_to session[:checkout_url], allow_other_host: true, status: :see_other
      return
    end

    unless Rails.env.local?
      redirect_to billing_path, alert: "PayMongo is not configured on this server. Set PAYMONGO_SECRET_KEY to accept GCash/Maya."
      return
    end

    Current.user.update!(plan: "pro")
    redirect_to billing_path, notice: "Pro unlocked for this local account (PayMongo key not set)."
  rescue Billing::Paymongo::Error => e
    redirect_to billing_path, alert: e.message
  end
end
