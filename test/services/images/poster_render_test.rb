require "test_helper"

class ImagesPosterRenderTest < ActiveSupport::TestCase
  test "enabled by default off Render" do
    without_env("POSTER_RENDER_ENABLED", "RENDER") do
      assert Images::PosterRender.enabled?
    end
  end

  test "disabled on Render unless explicitly opted in" do
    with_env("RENDER" => "true") do
      without_env("POSTER_RENDER_ENABLED") do
        refute Images::PosterRender.enabled?
      end
    end
  end

  test "POSTER_RENDER_ENABLED true wins on Render" do
    with_env("RENDER" => "true", "POSTER_RENDER_ENABLED" => "true") do
      assert Images::PosterRender.enabled?
    end
  end

  test "POSTER_RENDER_ENABLED false wins off Render" do
    with_env("POSTER_RENDER_ENABLED" => "false") do
      without_env("RENDER") do
        refute Images::PosterRender.enabled?
      end
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
