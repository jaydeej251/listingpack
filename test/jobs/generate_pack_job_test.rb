require "test_helper"

class GeneratePackJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creates a ready pack with captions and enqueues first poster batch" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    assert_enqueued_with(job: RenderPosterBatchJob) do
      GeneratePackJob.perform_now(listing.id)
    end

    listing.reload
    pack = listing.latest_pack
    assert_equal "ready", listing.status
    assert_equal "ready", pack.status
    assert pack.facebook_caption.present?
    assert_equal GeneratedAsset.generation_keys.size, pack.generated_assets.count
  end

  test "poster batch failure still leaves ready copy with a poster warning" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    stub_singleton(Images::Chrome, :path, nil) do
      perform_enqueued_jobs only: [ GeneratePackJob, RenderPosterBatchJob ] do
        GeneratePackJob.perform_later(listing.id)
      end
    end

    pack = listing.reload.latest_pack
    assert_equal "ready", pack.status
    assert pack.facebook_caption.present?
    assert_match(/every poster failed|Some posters failed|groups of three/i, pack.error_message.to_s)
    assert_equal GeneratedAsset.generation_keys.size, pack.generated_assets.count
    pack.generated_assets.each do |asset|
      assert asset.persisted?
      assert_not asset.image.attached?
      assert_equal "failed", asset.status
    end
  end

  test "two batches cover all six formats by default" do
    assert_equal 2, GeneratedAsset.batches.size
    assert_equal 3, GeneratedAsset.batches[0].size
    assert_equal 3, GeneratedAsset.batches[1].size
    assert_equal GeneratedAsset::TEMPLATE_KEYS.sort, GeneratedAsset.generation_keys.sort
  end

  test "core format set only enqueues square batch" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    previous = ENV["POSTER_FORMAT_SET"]
    ENV["POSTER_FORMAT_SET"] = "core"
    stub_singleton(Images::Chrome, :path, nil) do
      perform_enqueued_jobs only: [ GeneratePackJob, RenderPosterBatchJob ] do
        GeneratePackJob.perform_later(listing.id)
      end
    end

    pack = listing.reload.latest_pack
    assert_equal GeneratedAsset::CORE_TEMPLATE_KEYS.sort, pack.generated_assets.map(&:template_key).sort
  ensure
    previous.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous
  end

  test "missing listing photo leaves a re-upload or failure warning after batches" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )
    blob = listing.photos.first.blob
    blob.service.delete(blob.key)

    stub_singleton(Images::Chrome, :path, nil) do
      perform_enqueued_jobs only: [ GeneratePackJob, RenderPosterBatchJob ] do
        GeneratePackJob.perform_later(listing.id)
      end
    end

    pack = listing.reload.latest_pack
    assert_equal "ready", pack.status
    assert pack.generated_assets.all?(&:failed?)
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
      perform_enqueued_jobs only: [ GeneratePackJob, RenderPosterBatchJob ] do
        GeneratePackJob.perform_later(listing.id, pack.id, false)
        GeneratePackJob.perform_later(listing.id, pack.id, false)
      end
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
