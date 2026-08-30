require "test_helper"

class AiPhotoVisionTest < ActiveSupport::TestCase
  test "enabled by default" do
    without_env("AI_PHOTO_VISION") do
      assert Ai::PhotoVision.enabled?
    end
  end

  test "off false and none disable vision" do
    %w[off false none OFF False].each do |value|
      with_env("AI_PHOTO_VISION" => value) do
        assert_not Ai::PhotoVision.enabled?, "expected #{value.inspect} to disable vision"
      end
    end
  end

  test "on enables vision" do
    with_env("AI_PHOTO_VISION" => "on") do
      assert Ai::PhotoVision.enabled?
    end
  end
end
