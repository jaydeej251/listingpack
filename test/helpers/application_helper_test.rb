require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "app brand renders a fixed-size icon and wordmark" do
    html = app_brand(variant: :header)
    assert_match(/logo-icon\.png/, html)
    assert_match(/width="32"/, html)
    assert_match(/height="32"/, html)
    assert_match(/width:32px/, html)
    assert_match(/ListingPack/, html)
  end

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

  test "admin quota summary is packs used not remaining" do
    free = users(:one)
    free.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 1)
    assert_equal "1 of 3 packs used", admin_quota_summary(free)
    assert_equal "unlimited packs", admin_quota_summary(users(:two))
  end

  test "facebook sharer encodes the listing url" do
    url = facebook_sharer_url("https://listingpack.test/l/abc")
    assert_includes url, "https://www.facebook.com/sharer/sharer.php?u="
    assert_includes url, "https%3A%2F%2Flistingpack.test%2Fl%2Fabc"
  end
end
