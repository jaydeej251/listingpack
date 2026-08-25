class Billing::Checkout
  def initialize(user:)
    @user = user
  end

  def call
    client = Billing::Paymongo.new
    session = client.create_checkout_session(user: @user)
    @user.update!(paymongo_checkout_session_id: session[:id])
    session
  end
end
