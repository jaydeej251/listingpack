require "test_helper"

class AiPhotoVisionTest < ActiveSupport::TestCase
  test "enabled by default when not using ollama" do
    without_env("AI_PHOTO_VISION", "OLLAMA_API_KEY", "OPENAI_API_URL") do
      assert Ai::PhotoVision.enabled?
    end
  end

  test "defaults off when ollama api key is set" do
    without_env("AI_PHOTO_VISION", "OPENAI_API_URL") do
      with_env("OLLAMA_API_KEY" => "ollama-test") do
        assert_not Ai::PhotoVision.enabled?
      end
    end
  end

  test "off false and none disable vision" do
    %w[off false none OFF False].each do |value|
      with_env("AI_PHOTO_VISION" => value) do
        assert_not Ai::PhotoVision.enabled?, "expected #{value.inspect} to disable vision"
      end
    end
  end

  test "on enables vision even with ollama" do
    with_env("AI_PHOTO_VISION" => "on", "OLLAMA_API_KEY" => "ollama-test") do
      assert Ai::PhotoVision.enabled?
    end
  end
end
