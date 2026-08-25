class BillingsController < ApplicationController
  def show
    Current.user.reset_quota_if_needed!
  end

  def update
    unless Rails.env.local?
      redirect_to billing_path, alert: "GCash and Maya via PayMongo are coming soon. Pro is not available for purchase yet."
      return
    end

    Current.user.update!(plan: "pro")
    redirect_to billing_path, notice: "Pro unlocked for this local account. PayMongo will replace this stub later."
  end
end
