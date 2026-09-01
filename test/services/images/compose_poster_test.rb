require "test_helper"

class ImagesComposePosterTest < ActiveSupport::TestCase
  test "renders a png for just_listed" do
    listing = listings(:bgc_condo)
    attach_photo!(listing)
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)
    pack.generated_assets.create!(template_key: "just_listed", status: "pending")

    asset = Images::ComposePoster.new(pack, "just_listed", watermark: true).call

    assert_equal "ready", asset.status
    assert asset.image.attached?
    assert_operator asset.image.byte_size, :>, 10_000
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "stack_down leaves space between lines" do
    renderer = Images::ComposePoster.allocate
    canvas = Images::PosterCanvas.new(400, 400, background: [ 255, 255, 255 ])

    first_end = renderer.send(:stack_down, canvas, "JUST LISTED", width: 300, size: 18, x: 10, y: 10, gap: 8, rgb: [ 0, 0, 0 ], font: "Sans Bold")
    second_end = renderer.send(:stack_down, canvas, "1br for sale", width: 300, size: 48, x: 10, y: first_end, gap: 12, rgb: [ 0, 0, 0 ], font: "Serif Bold")

    first_block = renderer.send(:copy_block, "JUST LISTED", width: 300, size: 18, rgb: [ 0, 0, 0 ], font: "Sans Bold")
    assert_operator first_end, :>=, 10 + first_block.height + 8
    assert_operator second_end, :>, first_end
    assert_operator first_block.height, :<, 36
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "long titles shrink instead of overflowing the title budget" do
    renderer = Images::ComposePoster.allocate
    title = "Fully Finished House and Lot with Garden Near the Cavite Exit in General Trias"
    block = renderer.send(:copy_block, title, width: 968, size: 72, font: "Serif Bold", max_height: 185)

    assert block
    assert_operator block.height, :<=, 185
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "price card copy stays inside the beige panel for the launched townhouse listing" do
    listing = listings(:bgc_condo)
    listing.update!(
      title: "Fully Finished Townhouse",
      location: "General Trias, Cavite",
      price_amount: 3_700_000,
      bedrooms: 2,
      bathrooms: 1,
      floor_area: 40
    )
    attach_photo!(listing)
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)
    poster = Images::ComposePoster.new(pack, "price_card", watermark: true)
    layout = poster.send(:price_card_layout, 1080, 1080)

    png = poster.send(:render_price_card, 1080, 1080)
    image = Vips::Image.new_from_buffer(png, "")

    assert_equal 1080, image.width
    assert_equal 1080, image.height
    assert_operator layout[:photo_h] + 36 + 20, :<=, layout[:max_y]
    assert_operator layout[:body_y], :<, layout[:max_y]
    assert_operator layout[:max_y], :<=, 1080 - layout[:footer_h]

    paper = image.crop(56, layout[:photo_h] + 8, 200, 24)
    assert_operator paper[0].avg, :>=, 200
    assert_operator paper[1].avg, :>=, 190
    assert_operator paper[2].avg, :>=, 180
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "renders square price and agent cards" do
    listing = listings(:bgc_condo)
    attach_photo!(listing)
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)

    %w[price_card agent_card].each do |key|
      asset = Images::ComposePoster.new(pack, key).call
      assert_equal "ready", asset.status, "#{key} should render"
      assert asset.image.attached?
    end
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "every pack format renders at the declared size with a long title" do
    listing = listings(:bgc_condo)
    listing.update!(
      title: "Fully Finished Townhouse",
      location: "General Trias, Cavite",
      price_amount: 3_700_000,
      bedrooms: 2,
      bathrooms: 1,
      floor_area: 40
    )
    attach_photo!(listing)
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)

    GeneratedAsset::TEMPLATE_KEYS.each do |key|
      asset = Images::ComposePoster.new(pack, key, watermark: true).call
      width, height = GeneratedAsset.window_size(key)
      image = Vips::Image.new_from_buffer(asset.image.download, "")

      assert_equal "ready", asset.status, "#{key} should render"
      assert_equal width, image.width, "#{key} width"
      assert_equal height, image.height, "#{key} height"
    end
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "just_listed title block does not collide with the price row" do
    renderer = Images::ComposePoster.allocate
    canvas = Images::PosterCanvas.new(1080, 1080, background: [ 20, 33, 61 ])

    y = 1024
    y = renderer.send(:stack_up, canvas, "Maria Santos · 09170000000", width: 968, size: 22, x: 56, y: y, gap: 0)
    y = renderer.send(:stack_up, canvas, "Parking included · Pag-IBIG", width: 968, size: 20, x: 56, y: y, gap: 12)
    y = renderer.send(:stack_up, canvas, "2BR · 1BA · 40 sqm", width: 968, size: 24, x: 56, y: y, gap: 12)
    price_bottom = y
    y = renderer.send(:stack_up, canvas, "₱3,700,000", width: 968, size: 42, x: 56, y: y, gap: 10, font: "Sans Bold")
    title_bottom = y
    above_title = renderer.send(:stack_up, canvas, "Fully Finished Townhouse", width: 968, size: 72, x: 56, y: y, gap: 18, font: "Serif Bold", max_height: 185)

    assert_operator title_bottom, :<=, price_bottom
    assert_operator title_bottom - above_title, :<=, 185 + 18
    assert_operator above_title, :>, 160, "title should not climb into the JUST LISTED badge"
  rescue LoadError, StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  private
    def attach_photo!(listing)
      listing.photos.attach(
        io: File.open(Rails.root.join("public/icon.png")),
        filename: "listing.png",
        content_type: "image/png"
      )
    end

    def vips_unavailable?(error)
      error.is_a?(LoadError) || error.class.name == "Vips::Error"
    end
end
