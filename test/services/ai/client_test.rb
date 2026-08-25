require "test_helper"

class AiClientTest < ActiveSupport::TestCase
  setup do
    @client = Ai::Client.new
    @saved = %w[OPENAI_API_KEY OPENROUTER_API_KEY OPENAI_API_URL OPENAI_MODEL APP_HOST].index_with { |key| ENV[key] }
  end

  teardown do
    @saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "blank keys are not configured" do
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("OPENROUTER_API_KEY")
    assert_not @client.configured?
  end

  test "openai key hits openai with gpt-4o-mini" do
    ENV.delete("OPENROUTER_API_KEY")
    ENV.delete("OPENAI_API_URL")
    ENV.delete("OPENAI_MODEL")
    ENV["OPENAI_API_KEY"] = "sk-proj-test"

    assert @client.configured?
    assert_equal Ai::Client::OPENAI_CHAT_URL, @client.send(:chat_url)
    assert_equal "gpt-4o-mini", @client.send(:model)
    assert_not @client.send(:using_openrouter?)
  end

  test "openrouter env var routes to openrouter and prefixes the default model" do
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("OPENAI_API_URL")
    ENV.delete("OPENAI_MODEL")
    ENV["OPENROUTER_API_KEY"] = "sk-or-v1-test"

    assert @client.configured?
    assert @client.send(:using_openrouter?)
    assert_equal Ai::Client::OPENROUTER_CHAT_URL, @client.send(:chat_url)
    assert_equal "openai/gpt-4o-mini", @client.send(:model)
  end

  test "openai env var that is actually an openrouter key auto-routes" do
    ENV.delete("OPENROUTER_API_KEY")
    ENV.delete("OPENAI_API_URL")
    ENV.delete("OPENAI_MODEL")
    ENV["OPENAI_API_KEY"] = "sk-or-v1-pasted-into-openai-slot"

    assert @client.send(:using_openrouter?)
    assert_equal Ai::Client::OPENROUTER_CHAT_URL, @client.send(:chat_url)
    assert_equal "openai/gpt-4o-mini", @client.send(:model)
  end

  test "openrouter prefixes a bare openai model name" do
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("OPENAI_API_URL")
    ENV["OPENROUTER_API_KEY"] = "sk-or-v1-test"
    ENV["OPENAI_MODEL"] = "gpt-4o-mini"

    assert_equal "openai/gpt-4o-mini", @client.send(:model)
  end

  test "openrouter keeps a provider-prefixed model" do
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("OPENAI_API_URL")
    ENV["OPENROUTER_API_KEY"] = "sk-or-v1-test"
    ENV["OPENAI_MODEL"] = "google/gemini-2.0-flash-001"

    assert_equal "google/gemini-2.0-flash-001", @client.send(:model)
  end
end
