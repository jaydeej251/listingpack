require "test_helper"

class ImagesRenderPosterBatchTest < ActiveSupport::TestCase
  test "chrome startup failure marks keys failed instead of raising" do
    listing = listings(:bgc_condo)
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)
    pack.generated_assets.create!(template_key: "just_listed", status: "pending")

    stub_singleton(Images::Chrome, :path, "/usr/bin/chromium") do
      stub_singleton(Images::PosterBrowser, :open, ->(*) { raise Images::PosterBrowser::Error, "Chrome took too long to start" }) do
        result = Images::RenderPosterBatch.new(pack, [ "just_listed" ]).call
        assert_equal 0, result[:rendered]
        assert_equal "failed", pack.generated_assets.find_by!(template_key: "just_listed").status
        assert_match(/too long/i, pack.generated_assets.find_by!(template_key: "just_listed").error_message)
      end
    end
  end

  test "disabled marks keys failed without opening chrome" do
    listing = listings(:bgc_condo)
    pack = listing.content_packs.create!(language: listing.language, status: "ready", stage: listing.stage)
    pack.generated_assets.create!(template_key: "just_listed", status: "pending")

    chrome_opened = false
    stub_singleton(Images::PosterBrowser, :open, ->(*) { chrome_opened = true }) do
      with_env("POSTER_RENDER_ENABLED" => "false") do
        result = Images::RenderPosterBatch.new(pack, [ "just_listed" ]).call
        assert_equal 0, result[:rendered]
        refute chrome_opened
        assert_equal "failed", pack.generated_assets.find_by!(template_key: "just_listed").status
        assert_match(/paused on this server/i, pack.generated_assets.find_by!(template_key: "just_listed").error_message)
      end
    end
  end
end
