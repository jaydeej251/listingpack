require "test_helper"

class GeneratedAssetTest < ActiveSupport::TestCase
  test "formats cover square story landscape and banner sizes" do
    assert_equal %w[just_listed price_card agent_card story landscape fb_banner], GeneratedAsset::TEMPLATE_KEYS
    assert_equal [ 1080, 1080 ], GeneratedAsset.window_size("just_listed")
    assert_equal [ 1080, 1920 ], GeneratedAsset.window_size("story")
    assert_equal [ 1920, 1080 ], GeneratedAsset.window_size("landscape")
    assert_equal [ 1200, 628 ], GeneratedAsset.window_size("fb_banner")
    assert_equal "1080 / 1920", GeneratedAsset.aspect_ratio_css("story")
  end

  test "generation_keys respects POSTER_FORMAT_SET" do
    previous = ENV["POSTER_FORMAT_SET"]
    ENV["POSTER_FORMAT_SET"] = "core"
    assert_equal GeneratedAsset::CORE_TEMPLATE_KEYS, GeneratedAsset.generation_keys

    ENV["POSTER_FORMAT_SET"] = "all"
    assert_equal GeneratedAsset::TEMPLATE_KEYS, GeneratedAsset.generation_keys
  ensure
    previous.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous
  end
end
