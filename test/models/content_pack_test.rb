require "test_helper"

class ContentPackTest < ActiveSupport::TestCase
  test "poster_states only reports formats in the active set" do
    previous = ENV["POSTER_FORMAT_SET"]
    ENV["POSTER_FORMAT_SET"] = "demo"
    listing = listings(:bgc_condo)
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Hi")
    pack.generated_assets.create!(template_key: "just_listed", status: "rendering")

    assert_equal({ "just_listed" => "rendering" }, pack.poster_states)
    assert pack.posters_in_progress?
    refute pack.posters_complete?
    assert_equal 0, pack.poster_ready_count
    assert_equal 1, pack.poster_total_count
  ensure
    previous.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous
  end

  test "poster_ready_count counts attached images even when status lags" do
    listing = listings(:bgc_condo)
    pack = listing.content_packs.create!(status: "ready", facebook_caption: "Hi")
    asset = pack.generated_assets.create!(template_key: "just_listed", status: "rendering")
    asset.image.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "poster.png",
      content_type: "image/png"
    )

    assert_equal 1, pack.poster_ready_count
    assert_equal "ready", pack.poster_states["just_listed"]
  end
end
