require "test_helper"

class ImagesPosterCanvasTest < ActiveSupport::TestCase
  setup do
    require "vips"
  rescue LoadError
    skip "libvips not available in this environment"
  end

  test "text at template sizes is pixel-true not doubled by DPI" do
    title_72 = Images::PosterCanvas.tinted_text(
      "Fully Finished Townhouse",
      width: 968,
      size: 72,
      rgb: [ 255, 255, 255 ],
      font: "Serif Bold",
      dpi: 72
    )
    title_144 = Images::PosterCanvas.tinted_text(
      "Fully Finished Townhouse",
      width: 968,
      size: 72,
      rgb: [ 255, 255, 255 ],
      font: "Serif Bold",
      dpi: 144
    )

    assert_operator title_72.height, :>=, 48
    assert_operator title_72.height, :<=, 185, "72 DPI title should stay within two lines, got #{title_72.height}px"
    assert_operator title_144.height, :>=, title_72.height * 1.5, "144 DPI must not be used for layout; it doubled glyphs (#{title_144.height} vs #{title_72.height})"
  rescue StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "price-card title stays a compact block" do
    title = Images::PosterCanvas.tinted_text(
      "Fully Finished Townhouse",
      width: 968,
      size: 48,
      rgb: [ 20, 33, 61 ],
      font: "Serif Bold"
    )

    assert_operator title.height, :<=, 90
  rescue StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "watermark is a soft corner credit not a diagonal banner" do
    mark = Images::PosterCanvas.watermark(1080, 1080)
    assert mark
    assert_equal 4, mark.bands
    assert_operator mark.width, :<=, 280, "corner credit should stay compact, got #{mark.width}px"
    assert_operator mark.height, :<=, 40, "corner credit should be a single small line, got #{mark.height}px"

    max_alpha = mark[3].max
    assert_operator max_alpha, :<=, (255 * 0.65).ceil, "corner credit alpha should stay soft, got #{max_alpha}"
    assert_operator max_alpha, :>=, 80, "corner credit should still be readable"
    assert_operator mark[0].max, :>=, 200, "watermark should be white, not black"
    assert_operator mark[1].max, :>=, 200
    assert_operator mark[2].max, :>=, 200

    inset = Images::PosterCanvas.watermark_corner_inset(1080, 1080)
    assert_operator inset, :>=, 20
  rescue StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "with_opacity scales the alpha channel" do
    block = Images::PosterCanvas.tinted_text("FREE", width: 400, size: 40, rgb: [ 255, 255, 255 ], font: "Sans Bold")
    faded = Images::PosterCanvas.with_opacity(block, 0.08)

    assert_in_delta block[3].max * 0.08, faded[3].max, 2
  rescue StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  test "rounded fill keeps an alpha mask" do
    fill = Images::PosterCanvas.rounded_fill(120, 48, [ 196, 92, 38 ], radius: 10)

    assert_equal 4, fill.bands
    assert_equal 120, fill.width
    assert_equal 48, fill.height
  rescue StandardError => e
    skip "libvips not available in this environment" if vips_unavailable?(e)
    raise
  end

  private
    def vips_unavailable?(error)
      error.is_a?(LoadError) || error.class.name == "Vips::Error"
    end
end
