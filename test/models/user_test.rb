require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "free users get three packs per month" do
    user = users(:one)
    user.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 0)

    assert user.can_generate_pack?
    3.times { assert user.consume_pack_quota! }
    refute user.consume_pack_quota!
    refute user.reload.can_generate_pack?
    assert_equal 0, user.remaining_packs
  end

  test "refund restores a free pack credit" do
    user = users(:one)
    user.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 2)

    user.refund_pack_quota!
    assert_equal 1, user.reload.packs_count_in_period
    assert_equal 2, user.remaining_packs
  end

  test "pro users are not quota limited" do
    user = users(:two)
    assert user.pro?
    assert_equal Float::INFINITY, user.remaining_packs
    assert user.consume_pack_quota!
    assert user.can_generate_pack?
  end

  test "creates a brand kit after signup" do
    user = User.create!(email_address: "new@example.com", password: "password123")
    assert user.brand_kit.present?
  end
end
