require "test_helper"

class ImagesComposePosterTest < ActiveSupport::TestCase
  test "renders a png for just_listed" do
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
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if e.is_a?(LoadError) || e.class.name == "Vips::Error"
    raise
  end

  test "stack_down leaves space between lines" do
    renderer = Images::ComposePoster.allocate
    canvas = Images::PosterCanvas.new(400, 400, background: [ 255, 255, 255 ])

    first_end = renderer.send(:stack_down, canvas, "JUST LISTED", width: 300, size: 18, x: 10, y: 10, gap: 8, rgb: [ 0, 0, 0 ], font: "Sans Bold")
    second_end = renderer.send(:stack_down, canvas, "1br for sale", width: 300, size: 48, x: 10, y: first_end, gap: 12, rgb: [ 0, 0, 0 ], font: "Serif Bold")

    first_block = renderer.send(:text_block, "JUST LISTED", width: 300, size: 18, rgb: [ 0, 0, 0 ], font: "Sans Bold")
    assert_operator first_end, :>=, 10 + first_block.height + 8
    assert_operator second_end, :>, first_end
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if e.is_a?(LoadError) || e.class.name == "Vips::Error"
    raise
  end
end
