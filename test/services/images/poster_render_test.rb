require "test_helper"

class ImagesPosterRenderTest < ActiveSupport::TestCase
  test "defaults to vips renderer" do
    without_env("POSTER_RENDERER") do
      assert Images::PosterRender.vips?
      assert Images::PosterRender.enabled?
    end
  end

  test "POSTER_RENDERER off disables rendering" do
    with_env("POSTER_RENDERER" => "off") do
      refute Images::PosterRender.enabled?
    end
  end

  test "disable_pack! fails in-progress posters and leaves copy ready" do
    listing = listings(:bgc_condo)
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)
    rendering = pack.generated_assets.create!(template_key: "just_listed", status: "rendering")
    pending = pack.generated_assets.create!(template_key: "story", status: "pending")
    ready = pack.generated_assets.create!(template_key: "price_card", status: "ready")

    Images::PosterRender.disable_pack!(pack)

    assert_equal "failed", rendering.reload.status
    assert_equal "failed", pending.reload.status
    assert_equal "ready", ready.reload.status
    assert_equal "ready", pack.reload.status
    assert_match(/paused on this server/i, pack.error_message)
  end
end
