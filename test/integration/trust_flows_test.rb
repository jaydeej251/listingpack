require "test_helper"

class TrustFlowsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "free user at zero packs saves listing without consuming quota or enqueueing" do
    user = users(:one)
    user.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 3)
    sign_in user

    assert_no_enqueued_jobs only: GeneratePackJob do
      assert_difference -> { user.listings.count }, 1 do
        post listings_path, params: {
          listing: {
            title: "Quota blocked unit",
            location: "QC",
            language: "taglish",
            stage: "listed",
            listing_type: "for_sale",
            financing: "negotiable",
            photos: [ upload_icon ]
          }
        }
      end
    end

    listing = user.listings.order(:created_at).last
    assert_redirected_to listing_path(listing)
    follow_redirect!
    assert_match(/upgrade on Plan|Free plan includes/i, flash[:alert].to_s + response.body)
    assert_equal 3, user.reload.packs_count_in_period
    assert_equal "draft", listing.reload.status
  end

  test "generate again resets price_confirmed" do
    user = users(:two)
    sign_in user
    listing = user.listings.new(
      title: "Confirmed listing",
      location: "BGC",
      language: "taglish",
      stage: "listed",
      listing_type: "for_sale",
      financing: "negotiable",
      status: "ready",
      price_confirmed: true
    )
    listing.photos.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "x.png", content_type: "image/png")
    listing.save!

    assert_enqueued_with(job: GeneratePackJob) do
      post listing_content_packs_path(listing)
    end

    assert_not listing.reload.price_confirmed?
    assert_equal "generating", listing.status
  end

  test "billing unlock is blocked outside local environments" do
    user = users(:one)
    sign_in user
    assert user.free?

    production = ActiveSupport::StringInquirer.new("production")
    stub_singleton(Rails, :env, production) do
      patch billing_path
      assert_redirected_to billing_path
      assert_equal "free", user.reload.plan
      assert_match(/PayMongo|coming soon/i, flash[:alert])
    end
  end

  test "billing unlock works in local environments" do
    user = users(:one)
    sign_in user

    patch billing_path
    assert_redirected_to billing_path
    assert_equal "pro", user.reload.plan
  end

  test "calendar retry does not consume quota" do
    user = users(:one)
    user.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 2)
    sign_in user

    calendar = user.weekly_calendars.create!(
      week_start: Time.zone.today.beginning_of_week.to_date,
      focus_area: "BGC",
      status: "failed",
      error_message: "boom"
    )

    assert_enqueued_with(job: GenerateCalendarJob) do
      post retry_weekly_calendar_path(calendar)
    end

    assert_equal 2, user.reload.packs_count_in_period
    assert_equal "generating", calendar.reload.status
  end

  test "failed calendar show offers free retry" do
    user = users(:two)
    sign_in user
    calendar = user.weekly_calendars.create!(
      week_start: Time.zone.today.beginning_of_week.to_date,
      focus_area: "BGC",
      status: "failed",
      error_message: "timeout"
    )

    get weekly_calendar_path(calendar)
    assert_response :success
    assert_select "form[action=?]", retry_weekly_calendar_path(calendar)
    assert_match(/does not use a free pack/, response.body)
  end

  private
    def sign_in(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
      follow_redirect!
    end

    def upload_icon
      Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png")
    end
end
