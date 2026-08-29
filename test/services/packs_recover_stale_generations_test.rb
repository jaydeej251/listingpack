require "test_helper"

class PacksRecoverStaleGenerationsTest < ActiveSupport::TestCase
  test "marks stale generating listings failed" do
    listing = listings(:bgc_condo)
    listing.update!(status: "generating", updated_at: 20.minutes.ago)
    pack = listing.content_packs.create!(
      language: listing.language,
      status: "generating",
      stage: listing.stage,
      updated_at: 20.minutes.ago
    )

    assert_equal 1, Packs::RecoverStaleGenerations.call(stale_after: 8.minutes)

    assert_equal "failed", listing.reload.status
    assert_equal "failed", pack.reload.status
    assert_match(/interrupted/i, pack.error_message)
  end

  test "syncs listing to ready when pack already finished" do
    listing = listings(:bgc_condo)
    listing.update!(status: "generating", updated_at: 20.minutes.ago)
    listing.content_packs.create!(
      language: listing.language,
      status: "ready",
      stage: listing.stage,
      facebook_caption: "Ready copy",
      updated_at: 1.minute.ago
    )

    Packs::RecoverStaleGenerations.call(stale_after: 8.minutes)

    assert_equal "ready", listing.reload.status
  end

  test "leaves fresh generating listings alone" do
    listing = listings(:bgc_condo)
    listing.update!(status: "generating", updated_at: 1.minute.ago)

    assert_equal 0, Packs::RecoverStaleGenerations.call(stale_after: 8.minutes)
    assert_equal "generating", listing.reload.status
  end

  test "recover_listing_if_stale! only acts after the cutoff" do
    listing = listings(:bgc_condo)
    listing.update!(status: "generating", updated_at: 1.minute.ago)
    Packs::RecoverStaleGenerations.recover_listing_if_stale!(listing, stale_after: 8.minutes)
    assert_equal "generating", listing.reload.status

    listing.update!(updated_at: 20.minutes.ago)
    listing.content_packs.create!(language: listing.language, status: "generating", stage: listing.stage)
    Packs::RecoverStaleGenerations.recover_listing_if_stale!(listing, stale_after: 8.minutes)
    assert_equal "failed", listing.reload.status
  end

  test "marks stale calendars failed" do
    calendar = users(:one).weekly_calendars.create!(
      week_start: Date.new(2026, 8, 24),
      focus_area: "BGC",
      status: "generating",
      updated_at: 20.minutes.ago
    )

    Packs::RecoverStaleGenerations.call(stale_after: 8.minutes)

    assert_equal "failed", calendar.reload.status
    assert_match(/interrupted/i, calendar.error_message)
  end

  test "unsticks rendering posters immediately when poster rendering is disabled" do
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(
      language: listing.language,
      status: "ready",
      stage: listing.stage,
      facebook_caption: "Ready copy"
    )
    pack.generated_assets.create!(template_key: "just_listed", status: "rendering")

    with_env("POSTER_RENDERER" => "off") do
      Packs::RecoverStaleGenerations.recover_listing_if_stale!(listing)
    end

    assert_equal "ready", listing.reload.status
    assert_equal "failed", pack.generated_assets.find_by!(template_key: "just_listed").reload.status
    assert_match(/paused on this server/i, pack.reload.error_message)
  end

  test "fails stale rendering posters on a ready pack when vips is enabled" do
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(
      language: listing.language,
      status: "ready",
      stage: listing.stage,
      facebook_caption: "Ready copy"
    )
    asset = pack.generated_assets.create!(template_key: "just_listed", status: "rendering")
    asset.update_column(:updated_at, 20.minutes.ago)

    without_env("POSTER_RENDERER") do
      Packs::RecoverStaleGenerations.recover_listing_if_stale!(listing, stale_after: 8.minutes)
    end

    assert_equal "ready", listing.reload.status
    assert_equal "failed", asset.reload.status
    assert_match(/interrupted/i, asset.error_message)
  end

  test "leaves fresh rendering posters alone when vips is enabled" do
    listing = listings(:bgc_condo)
    listing.update!(status: "ready")
    pack = listing.content_packs.create!(
      language: listing.language,
      status: "ready",
      stage: listing.stage,
      facebook_caption: "Ready copy"
    )
    pack.generated_assets.create!(template_key: "just_listed", status: "rendering")

    without_env("POSTER_RENDERER") do
      Packs::RecoverStaleGenerations.recover_listing_if_stale!(listing, stale_after: 8.minutes)
    end

    assert_equal "rendering", pack.generated_assets.find_by!(template_key: "just_listed").reload.status
  end
end
