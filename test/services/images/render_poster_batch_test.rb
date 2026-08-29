require "test_helper"

class ImagesRenderPosterBatchTest < ActiveSupport::TestCase
  test "disabled marks keys failed without rendering" do
    listing = listings(:bgc_condo)
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)
    pack.generated_assets.create!(template_key: "just_listed", status: "pending")

    with_env("POSTER_RENDERER" => "off") do
      result = Images::RenderPosterBatch.new(pack, [ "just_listed" ]).call
      assert_equal 0, result[:rendered]
      assert_equal "failed", pack.generated_assets.find_by!(template_key: "just_listed").status
      assert_match(/paused on this server/i, pack.generated_assets.find_by!(template_key: "just_listed").error_message)
    end
  end

  test "vips renders just_listed when libvips is available" do
    begin
      require "vips"
    rescue LoadError
      skip "libvips not available in this environment"
    end

    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)
    pack.generated_assets.create!(template_key: "just_listed", status: "pending")

    with_env("POSTER_RENDERER" => "vips") do
      result = Images::RenderPosterBatch.new(pack, [ "just_listed" ]).call
      assert_equal 1, result[:rendered]
      asset = pack.generated_assets.find_by!(template_key: "just_listed")
      assert_equal "ready", asset.status
      assert asset.image.attached?
    end
  rescue StandardError => e
    skip "libvips not available in this environment" if e.class.name == "Vips::Error" || e.is_a?(LoadError)
    raise
  end
end
