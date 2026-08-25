require "test_helper"

class GeneratePackJobTest < ActiveSupport::TestCase
  test "creates a ready pack with captions" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    GeneratePackJob.perform_now(listing.id)

    listing.reload
    pack = listing.latest_pack
    assert_equal "ready", listing.status
    assert_equal "ready", pack.status
    assert pack.facebook_caption.present?
  end

  test "png failure still leaves ready copy with a poster warning" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    stub_singleton(Images::Chrome, :path, nil) do
      GeneratePackJob.perform_now(listing.id)
    end

    pack = listing.reload.latest_pack
    assert_equal "ready", pack.status
    assert pack.facebook_caption.present?
    assert_match(/every poster failed|Some posters failed/i, pack.error_message.to_s)
    assert_equal GeneratedAsset::TEMPLATE_KEYS.size, pack.generated_assets.count
    pack.generated_assets.each do |asset|
      assert asset.persisted?
      assert_not asset.image.attached?
    end
  end

  test "retry reuses the same content pack row" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )
    pack = listing.content_packs.create!(language: listing.language, status: "generating", stage: listing.stage)

    stub_singleton(Images::Chrome, :path, nil) do
      GeneratePackJob.perform_now(listing.id, pack.id, false)
      GeneratePackJob.perform_now(listing.id, pack.id, false)
    end

    assert_equal 1, listing.content_packs.count
    assert_equal pack.id, listing.latest_pack.id
  end

  test "copy failure refunds a consumed free credit" do
    user = users(:one)
    user.update!(quota_period_start: Time.zone.today.beginning_of_month, packs_count_in_period: 1)
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    boom = Class.new(StandardError)
    stub_singleton(Ai::WritePack, :new, ->(*) { raise boom, "writer down" }) do
      assert_raises(boom) { GeneratePackJob.perform_now(listing.id, nil, true) }
    end

    assert_equal 0, user.reload.packs_count_in_period
    assert_equal "failed", listing.reload.status
  end
end
