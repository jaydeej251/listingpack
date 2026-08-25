class BillingMailer < ApplicationMailer
  def pro_receipt(user)
    @user = user
    mail subject: "ListingPack Pro is active", to: user.email_address
  end
end
