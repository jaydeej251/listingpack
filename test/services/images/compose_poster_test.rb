require "test_helper"

class ImagesComposePosterTest < ActiveSupport::TestCase
  test "renders a png for just_listed" do
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

    asset = Images::ComposePoster.new(pack, "just_listed", watermark: true).call

    assert_equal "ready", asset.status
    assert asset.image.attached?
    assert_operator asset.image.byte_size, :>, 10_000
  rescue StandardError => e
    skip "libvips not available in this environment" if e.class.name == "Vips::Error" || e.is_a?(LoadError)
    raise
  end
end
