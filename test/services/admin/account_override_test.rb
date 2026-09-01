require "test_helper"

class Admin::AccountOverrideTest < ActiveSupport::TestCase
  setup do
    @actor = users(:two)
    @user = users(:one)
    @user.update!(plan: "free", packs_count_in_period: 3, quota_period_start: Time.zone.today.beginning_of_month)
  end

  test "grant pro records an admin billing event" do
    Admin::AccountOverride.new(actor: @actor, user: @user, reason: "PayMongo paid, webhook missing").grant_pro!

    assert_equal "pro", @user.reload.plan
    event = @user.billing_events.order(:created_at).last
    assert_equal "admin", event.provider
    assert_equal "grant_pro", event.event_type
    assert_equal "PayMongo paid, webhook missing", event.payload["reason"]
    assert_equal @actor.email_address, event.payload["actor_email"]
    assert_equal "free", event.payload.dig("previous", "plan")
  end

  test "grant pro requires a reason" do
    error = assert_raises(Admin::AccountOverride::Error) do
      Admin::AccountOverride.new(actor: @actor, user: @user, reason: "no").grant_pro!
    end
    assert_match(/reason/i, error.message)
    assert_equal "free", @user.reload.plan
  end

  test "grant pro is a no-op when already pro" do
    @user.update!(plan: "pro")
    error = assert_raises(Admin::AccountOverride::Error) do
      Admin::AccountOverride.new(actor: @actor, user: @user, reason: "Already paid").grant_pro!
    end
    assert_match(/already on pro/i, error.message)
    assert_equal 0, BillingEvent.where(provider: "admin").count
  end

  test "revert free and reset quota" do
    @user.update!(plan: "pro")
    Admin::AccountOverride.new(actor: @actor, user: @user, reason: "Refunded in PayMongo").revert_free!
    assert_equal "free", @user.reload.plan

    @user.update!(packs_count_in_period: 3)
    Admin::AccountOverride.new(actor: @actor, user: @user, reason: "Failed pack ate a credit").reset_quota!
    @user.reload
    assert_equal 0, @user.packs_count_in_period
    assert_equal Time.zone.today.beginning_of_month, @user.quota_period_start
  end
end
