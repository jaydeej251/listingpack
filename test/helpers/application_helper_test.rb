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

  test "pack pill class follows generation status" do
    listing = listings(:bgc_condo)
    listing.status = "ready"
    assert_equal "pill pill-ready", pack_pill_class(listing)
  end
end
