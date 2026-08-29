require "test_helper"

class GeneratePackJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creates a ready pack with captions and schedules first poster for free users" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    freeze_time do
      assert_enqueued_with(job: RenderPosterBatchJob, at: GeneratePackJob::FIRST_POSTER_WAIT.from_now) do
        GeneratePackJob.perform_now(listing.id)
      end
    end

    listing.reload
    pack = listing.latest_pack
    assert_equal "ready", listing.status
    assert_equal "ready", pack.status
    assert pack.facebook_caption.present?
    assert_equal 1, pack.generated_assets.count
    assert_equal "just_listed", pack.generated_assets.first.template_key
    assert_equal "rendering", pack.generated_assets.find_by!(template_key: "just_listed").status
  end

  test "pro users get all poster rows" do
    listing = listings(:bgc_condo)
    listing.user.update!(plan: "pro")
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    GeneratePackJob.perform_now(listing.id)

    pack = listing.reload.latest_pack
    assert_equal GeneratedAsset::TEMPLATE_KEYS.size, pack.generated_assets.count
    assert_equal "rendering", pack.generated_assets.find_by!(template_key: "just_listed").status
    GeneratedAsset::TEMPLATE_KEYS.drop(1).each do |key|
      assert_equal "pending", pack.generated_assets.find_by!(template_key: key).status
    end
  end

  test "sequential poster failures still leave ready copy" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    stub_singleton(Images::ComposePoster, :new, ->(*) { raise Images::ComposePoster::Error, "vips down" }) do
      perform_enqueued_jobs only: [ GeneratePackJob, RenderPosterBatchJob ] do
        GeneratePackJob.perform_later(listing.id)
      end
    end

    pack = listing.reload.latest_pack
    assert_equal "ready", pack.status
    assert pack.facebook_caption.present?
    assert_equal 1, pack.generated_assets.count
    assert_equal "failed", pack.generated_assets.first.status
  end

  test "default mode is one poster per batch for pro" do
    previous = ENV["POSTER_RENDER_MODE"]
    ENV.delete("POSTER_RENDER_MODE")
    batches = GeneratedAsset.batches(user: users(:two))
    assert_equal 6, batches.size
    assert batches.all? { |batch| batch.size == 1 }
  ensure
    previous.nil? ? ENV.delete("POSTER_RENDER_MODE") : ENV["POSTER_RENDER_MODE"] = previous
  end

  test "batch mode groups posters by three for future Pro" do
    previous = ENV["POSTER_RENDER_MODE"]
    ENV["POSTER_RENDER_MODE"] = "batch"
    batches = GeneratedAsset.batches(user: users(:two))
    assert_equal 2, batches.size
    assert_equal 3, batches[0].size
    assert_equal 3, batches[1].size
  ensure
    previous.nil? ? ENV.delete("POSTER_RENDER_MODE") : ENV["POSTER_RENDER_MODE"] = previous
  end

  test "POSTER_FORMAT_SET demo env override creates one poster row" do
    listing = listings(:bgc_condo)
    listing.user.update!(plan: "pro")
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    previous = ENV["POSTER_FORMAT_SET"]
    ENV["POSTER_FORMAT_SET"] = "demo"
    GeneratePackJob.perform_now(listing.id)
    pack = listing.reload.latest_pack
    assert_equal GeneratedAsset::DEMO_TEMPLATE_KEYS, pack.generated_assets.map(&:template_key)
  ensure
    previous.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous
  end

  test "retry reuses the same content pack row" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )
    pack = listing.content_packs.create!(language: listing.language, status: "generating", stage: listing.stage)

    stub_singleton(Images::ComposePoster, :new, ->(*) { raise Images::ComposePoster::Error, "vips down" }) do
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

  test "skips poster jobs when renderer is off" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    with_env("POSTER_RENDERER" => "off") do
      assert_no_enqueued_jobs only: RenderPosterBatchJob do
        GeneratePackJob.perform_now(listing.id)
      end
    end

    pack = listing.reload.latest_pack
    assert_equal "ready", listing.status
    assert_equal "ready", pack.status
    assert pack.facebook_caption.present?
    assert_match(/paused on this server/i, pack.error_message)
    pack.generated_assets.each do |asset|
      assert_equal "failed", asset.status
      assert_not asset.image.attached?
    end
  end
end
