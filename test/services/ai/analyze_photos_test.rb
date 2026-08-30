require "test_helper"

class AiAnalyzePhotosTest < ActiveSupport::TestCase
  setup do
    @listing = listings(:bgc_condo)
    @listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )
  end

  test "returns disabled without calling the client when vision is off" do
    with_env("AI_PHOTO_VISION" => "off", "OPENROUTER_API_KEY" => "sk-or-v1-test") do
      result = Ai::AnalyzePhotos.new(@listing).call

      assert_equal "disabled", result[:model]
      assert_nil result[:text]
    end
  end

  test "calls the client when vision is on and a key is configured" do
    fake_client = Class.new do
      def configured? = true

      def data_uri_for(_blob) = "data:image/png;base64,abc"

      def chat(*)
        {
          text: '{"photo_notes":"balcony view"}',
          model: "openai/gpt-4o-mini",
          input_tokens: 10,
          output_tokens: 5
        }
      end
    end.new

    with_env("AI_PHOTO_VISION" => "on", "OPENROUTER_API_KEY" => "sk-or-v1-test") do
      stub_singleton(Ai::Client, :new, ->(*) { fake_client }) do
        result = Ai::AnalyzePhotos.new(@listing).call

        assert_equal "balcony view", result[:text]
        assert_equal "openai/gpt-4o-mini", result[:model]
      end
    end
  end
end
