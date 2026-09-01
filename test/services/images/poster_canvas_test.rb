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

  test "watermark is light and translucent instead of solid black" do
    mark = Images::PosterCanvas.watermark(1080, 1080)
    assert mark
    assert_equal 4, mark.bands

    max_alpha = mark[3].max
    assert_operator max_alpha, :<=, (255 * 0.16).ceil, "watermark alpha should stay faint, got #{max_alpha}"
    assert_operator max_alpha, :>=, 10, "watermark should still be visible"
    assert_operator mark[0].max, :>=, 200, "watermark should be white, not black"
    assert_operator mark[1].max, :>=, 200
    assert_operator mark[2].max, :>=, 200
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

  private
    def vips_unavailable?(error)
      error.is_a?(LoadError) || error.class.name == "Vips::Error"
    end
end
