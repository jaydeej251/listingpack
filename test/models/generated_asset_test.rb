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

  test "sequential mode is one key per batch" do
    previous = ENV["POSTER_RENDER_MODE"]
    ENV["POSTER_RENDER_MODE"] = "sequential"
    assert_equal GeneratedAsset::TEMPLATE_KEYS.map { |key| [ key ] }, GeneratedAsset.batches
  ensure
    previous.nil? ? ENV.delete("POSTER_RENDER_MODE") : ENV["POSTER_RENDER_MODE"] = previous
  end

  test "generation_keys respects POSTER_FORMAT_SET" do
    previous = ENV["POSTER_FORMAT_SET"]
    ENV["POSTER_FORMAT_SET"] = "core"
    assert_equal GeneratedAsset::CORE_TEMPLATE_KEYS, GeneratedAsset.generation_keys

    ENV["POSTER_FORMAT_SET"] = "demo"
    assert_equal GeneratedAsset::DEMO_TEMPLATE_KEYS, GeneratedAsset.generation_keys

    ENV["POSTER_FORMAT_SET"] = "all"
    assert_equal GeneratedAsset::TEMPLATE_KEYS.sort, GeneratedAsset.generation_keys.sort
  ensure
    previous.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous
  end

  test "demo mode can override the single poster format" do
    previous_set = ENV["POSTER_FORMAT_SET"]
    previous_single = ENV["POSTER_SINGLE_FORMAT"]
    ENV["POSTER_FORMAT_SET"] = "demo"
    ENV["POSTER_SINGLE_FORMAT"] = "fb_banner"
    assert_equal [ "fb_banner" ], GeneratedAsset.generation_keys
  ensure
    previous_set.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous_set
    previous_single.nil? ? ENV.delete("POSTER_SINGLE_FORMAT") : ENV["POSTER_SINGLE_FORMAT"] = previous_single
  end

  test "demo mode rejects unknown single format keys" do
    previous_set = ENV["POSTER_FORMAT_SET"]
    previous_single = ENV["POSTER_SINGLE_FORMAT"]
    ENV["POSTER_FORMAT_SET"] = "demo"
    ENV["POSTER_SINGLE_FORMAT"] = "not_a_format"
    assert_equal GeneratedAsset::DEMO_TEMPLATE_KEYS, GeneratedAsset.generation_keys
  ensure
    previous_set.nil? ? ENV.delete("POSTER_FORMAT_SET") : ENV["POSTER_FORMAT_SET"] = previous_set
    previous_single.nil? ? ENV.delete("POSTER_SINGLE_FORMAT") : ENV["POSTER_SINGLE_FORMAT"] = previous_single
  end
end
