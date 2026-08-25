require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "quota copy for free vs pro" do
    free = users(:one)
    free.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 1)

    assert_match(/2 of 3 free packs/, quota_copy(free))
    assert_equal [ 1, 3 ], quota_fraction(free)
    assert_equal "Pro · unlimited packs", quota_copy(users(:two))
    assert_nil quota_fraction(users(:two))
  end

  test "pack credit confirm states remaining credits, not 1 of 3" do
    free = users(:one)
    free.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 2)

    copy = pack_credit_confirm(free)
    assert_match(/You have 1 of 3 left this month/, copy)
    assert_match(/this is your last free pack/, copy)
    assert_match(/Listing packs and This week share/, copy)
    assert_no_match(/This uses 1 of 3 free packs this month/, copy)
  end

  test "pack credit confirm is omitted when no credits remain" do
    free = users(:one)
    free.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 3)

    assert_nil pack_credit_confirm(free)
    assert_nil pack_credit_confirm(users(:two))
  end

  test "pack pill class follows generation status" do
    listing = listings(:bgc_condo)
    listing.status = "ready"
    assert_equal "pill pill-ready", pack_pill_class(listing)
  end
end
