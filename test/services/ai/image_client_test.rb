require "test_helper"
require "base64"

class AiImageClientTest < ActiveSupport::TestCase
  setup do
    @client = Ai::ImageClient.new
    @saved = %w[
      OPENAI_API_KEY OPENAI_IMAGE_API_KEY OPENROUTER_API_KEY OLLAMA_API_KEY
      POSTER_BEAUTY OPENAI_IMAGE_MODEL OPENAI_IMAGE_SIZE OPENAI_IMAGE_QUALITY
      POSTER_BEAUTY_MAX_PHOTOS
    ].index_with { |key| ENV[key] }
  end

  teardown do
    @saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def clear!
    @saved.keys.each { |k| ENV.delete(k) }
  end

  test "not configured without openai key" do
    clear!
    assert_not @client.configured?
    assert_not @client.enabled?
  end

  test "openrouter keys are rejected for image beauty" do
    clear!
    ENV["OPENAI_API_KEY"] = "sk-or-v1-not-for-images"
    assert_not @client.configured?
  end

  test "openai key does not enable beauty until POSTER_BEAUTY=on" do
    clear!
    ENV["OPENAI_API_KEY"] = "sk-proj-test"
    assert @client.configured?
    assert_not @client.enabled?

    ENV["POSTER_BEAUTY"] = "on"
    assert @client.enabled?

    ENV["POSTER_BEAUTY"] = "off"
    assert_not @client.enabled?
  end

  test "OPENAI_IMAGE_API_KEY wins over chat key" do
    clear!
    ENV["OPENAI_API_KEY"] = "sk-or-v1-wrong"
    ENV["OPENAI_IMAGE_API_KEY"] = "sk-proj-images"
    assert @client.configured?
    assert_equal "sk-proj-images", @client.send(:api_key)
  end

  test "ollama-style tokens in OPENAI_API_KEY do not enable images" do
    clear!
    ENV["OPENAI_API_KEY"] = "ollama-cloud-token.not-openai"
    assert_not @client.configured?

    ENV["OPENAI_IMAGE_API_KEY"] = "sk-proj-images"
    assert @client.configured?
  end

  test "edit posts multipart and returns png bytes" do
    clear!
    ENV["OPENAI_API_KEY"] = "sk-proj-test"
    png = Base64.strict_encode64("fake-png-bytes")
    captured = {}

    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:request) do |req|
      captured[:content_type] = req["Content-Type"]
      captured[:body] = req.body
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:body) do
        { data: [ { b64_json: png } ], usage: { input_tokens: 10, output_tokens: 20 } }.to_json
      end
      response
    end

    stub_singleton(Net::HTTP, :new, ->(*) { fake_http }) do
      result = @client.edit(
        images: [ { filename: "hero.png", content_type: "image/png", bytes: "fake-image" } ],
        prompt: "Create a highly converting marketing material"
      )
      assert_equal "fake-png-bytes", result[:png_bytes]
      assert_equal 10, result[:input_tokens]
      assert_equal Ai::ImageClient::DEFAULT_MODEL, result[:model]
    end

    assert_includes captured[:content_type], "multipart/form-data"
    assert_includes captured[:body], "Create a highly converting"
    assert_includes captured[:body], "fake-image"
  end

  test "edit accepts utf8 prompts with binary image bytes" do
    clear!
    ENV["OPENAI_API_KEY"] = "sk-proj-test"
    png = Base64.strict_encode64("fake-png-bytes")

    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:request) do |_req|
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:body) do
        { data: [ { b64_json: png } ], usage: {} }.to_json
      end
      response
    end

    stub_singleton(Net::HTTP, :new, ->(*) { fake_http }) do
      result = @client.edit(
        images: [ { filename: "hero.png", content_type: "image/png", bytes: "\x89PNG".b } ],
        prompt: "Price ₱12,500,000 in BGC — highly converting"
      )
      assert_equal "fake-png-bytes", result[:png_bytes]
    end
  end
end
