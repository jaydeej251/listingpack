require "test_helper"

class WritePackTest < ActiveSupport::TestCase
  test "template fallback returns channel copy and seller report" do
    without_env("OPENROUTER_API_KEY", "OPENAI_API_KEY", "OLLAMA_API_KEY") do
      listing = listings(:bgc_condo)
      copy = Ai::WritePack.new(listing: listing).call

      assert_includes copy[:facebook_caption], "BGC"
      assert_includes copy[:marketplace_caption], "Pag-IBIG"
      assert_includes copy[:messenger_followup], "Parking"
      assert copy[:seller_report].present?
      assert copy[:facebook_group_caption].present?
      assert_equal "template_fallback", copy[:model]
    end
  end

  test "price reduced copy mentions the old price" do
    without_env("OPENROUTER_API_KEY", "OPENAI_API_KEY", "OLLAMA_API_KEY") do
      listing = listings(:bgc_condo)
      listing.stage = "price_reduced"
      listing.previous_price_amount = 13_500_000
      copy = Ai::WritePack.new(listing: listing).call

      assert_includes copy[:facebook_caption], "Price reduced"
      assert_includes copy[:facebook_caption], "13,500,000"
    end
  end

  test "falls back to template when the model returns empty content" do
    fake_client = Class.new do
      def configured? = true

      def chat(*)
        raise Ai::Client::Error, "AI returned empty content"
      end
    end.new

    listing = listings(:bgc_condo)
    stub_singleton(Ai::Client, :new, ->(*) { fake_client }) do
      copy = Ai::WritePack.new(listing: listing).call

      assert_equal "template_fallback", copy[:model]
      assert_includes copy[:facebook_caption], "BGC"
      assert_includes copy[:error_message], "empty content"
    end
  end

  test "rethrows auth errors so GeneratePackJob can retry" do
    fake_client = Class.new do
      def configured? = true

      def chat(*)
        raise Ai::Client::Error, "Missing Authentication header"
      end
    end.new

    listing = listings(:bgc_condo)
    stub_singleton(Ai::Client, :new, ->(*) { fake_client }) do
      assert_raises(Ai::Client::Error) { Ai::WritePack.new(listing: listing).call }
    end
  end

  test "falls back when parsed json has almost no caption fields" do
    fake_client = Class.new do
      def configured? = true

      def chat(*)
        { text: '{"unrelated":true}', model: "gpt-oss:20b", input_tokens: 1, output_tokens: 1 }
      end
    end.new

    listing = listings(:bgc_condo)
    stub_singleton(Ai::Client, :new, ->(*) { fake_client }) do
      copy = Ai::WritePack.new(listing: listing).call

      assert_equal "template_fallback", copy[:model]
      assert_includes copy[:facebook_caption], "BGC"
      assert_includes copy[:error_message], "missing caption fields"
    end
  end

  test "fills blank caption fields from the template" do
    fake_client = Class.new do
      def configured? = true

      def chat(*)
        {
          text: '{"facebook_caption":"Live FB","marketplace_caption":"Live Market","listing_description":"Live Desc"}',
          model: "gpt-oss:20b",
          input_tokens: 1,
          output_tokens: 2
        }
      end
    end.new

    listing = listings(:bgc_condo)
    stub_singleton(Ai::Client, :new, ->(*) { fake_client }) do
      copy = Ai::WritePack.new(listing: listing).call

      assert_equal "Live FB", copy[:facebook_caption]
      assert_equal "Live Market", copy[:marketplace_caption]
      assert copy[:seller_report].present?
      assert_equal "gpt-oss:20b", copy[:model]
    end
  end

  test "parses fenced json from the model" do
    fake_client = Class.new do
      def configured? = true

      def chat(*)
        {
          text: "```json\n{\"facebook_caption\":\"Live FB\",\"marketplace_caption\":\"M\",\"listing_description\":\"D\",\"facebook_group_caption\":\"G\",\"instagram_caption\":\"I\",\"facebook_ad_copy\":\"A\",\"messenger_followup\":\"F\",\"seller_report\":\"S\"}\n```",
          model: "gpt-oss:20b",
          input_tokens: 1,
          output_tokens: 2
        }
      end
    end.new

    listing = listings(:bgc_condo)
    stub_singleton(Ai::Client, :new, ->(*) { fake_client }) do
      copy = Ai::WritePack.new(listing: listing).call

      assert_equal "Live FB", copy[:facebook_caption]
      assert_equal "gpt-oss:20b", copy[:model]
      assert_nil copy[:error_message]
    end
  end
end
