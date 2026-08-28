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
  ensure
    previous.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous
  end
end
