require "test_helper"

class AiClientTest < ActiveSupport::TestCase
  setup do
    @client = Ai::Client.new
    @saved = %w[OPENAI_API_KEY OPENROUTER_API_KEY OLLAMA_API_KEY OPENAI_API_URL OPENAI_MODEL APP_HOST AI_MAX_OUTPUT_TOKENS AI_JSON_OBJECT].index_with { |key| ENV[key] }
  end

  teardown do
    @saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def clear_provider_env!
    %w[OPENAI_API_KEY OPENROUTER_API_KEY OLLAMA_API_KEY OPENAI_API_URL OPENAI_MODEL AI_JSON_OBJECT].each { |k| ENV.delete(k) }
  end

  test "blank keys are not configured" do
    clear_provider_env!
    assert_not @client.configured?
  end

  test "openai key hits openai with gpt-4o-mini" do
    clear_provider_env!
    ENV["OPENAI_API_KEY"] = "sk-proj-test"

    assert @client.configured?
    assert_equal Ai::Client::OPENAI_CHAT_URL, @client.send(:chat_url)
    assert_equal "gpt-4o-mini", @client.send(:model)
    assert_not @client.send(:using_openrouter?)
    assert_not @client.send(:using_ollama?)
  end

  test "openrouter env var routes to openrouter and prefixes the default model" do
    clear_provider_env!
    ENV["OPENROUTER_API_KEY"] = "sk-or-v1-test"

    assert @client.configured?
    assert @client.send(:using_openrouter?)
    assert_equal Ai::Client::OPENROUTER_CHAT_URL, @client.send(:chat_url)
    assert_equal "openai/gpt-4o-mini", @client.send(:model)
  end

  test "openai env var that is actually an openrouter key auto-routes" do
    clear_provider_env!
    ENV["OPENAI_API_KEY"] = "sk-or-v1-pasted-into-openai-slot"

    assert @client.send(:using_openrouter?)
    assert_equal Ai::Client::OPENROUTER_CHAT_URL, @client.send(:chat_url)
    assert_equal "openai/gpt-4o-mini", @client.send(:model)
  end

  test "ollama api key wins over leftover openrouter key" do
    clear_provider_env!
    ENV["OPENROUTER_API_KEY"] = "sk-or-v1-leftover"
    ENV["OLLAMA_API_KEY"] = "ollama-cloud-test-key"

    assert @client.send(:using_ollama?)
    assert_not @client.send(:using_openrouter?)
    assert_equal Ai::Client::OLLAMA_CHAT_URL, @client.send(:chat_url)
    assert_equal "gpt-oss:20b", @client.send(:model)
  end

  test "ollama openai-compatible url routes even with openrouter key present" do
    clear_provider_env!
    ENV["OPENROUTER_API_KEY"] = "sk-or-v1-leftover"
    ENV["OPENAI_API_KEY"] = "ollama-cloud-test-key"
    ENV["OPENAI_API_URL"] = "https://ollama.com/v1/chat/completions"
    ENV["OPENAI_MODEL"] = "gpt-oss:20b"

    assert @client.send(:using_ollama?)
    assert_equal "https://ollama.com/v1/chat/completions", @client.send(:chat_url)
    assert_equal "gpt-oss:20b", @client.send(:model)
  end

  test "ollama key ignores leftover non-ollama OPENAI_API_URL" do
    clear_provider_env!
    ENV["OLLAMA_API_KEY"] = "ollama-cloud-test-key"
    ENV["OPENAI_API_URL"] = "https://openrouter.ai/api/v1/chat/completions"

    assert @client.send(:using_ollama?)
    assert_equal Ai::Client::OLLAMA_CHAT_URL, @client.send(:chat_url)
  end

  test "openrouter prefixes a bare openai model name" do
    clear_provider_env!
    ENV["OPENROUTER_API_KEY"] = "sk-or-v1-test"
    ENV["OPENAI_MODEL"] = "gpt-4o-mini"

    assert_equal "openai/gpt-4o-mini", @client.send(:model)
  end

  test "openrouter keeps a provider-prefixed model" do
    clear_provider_env!
    ENV["OPENROUTER_API_KEY"] = "sk-or-v1-test"
    ENV["OPENAI_MODEL"] = "google/gemini-2.0-flash-001"

    assert_equal "google/gemini-2.0-flash-001", @client.send(:model)
  end

  test "AI_MAX_OUTPUT_TOKENS caps completion size when set" do
    ENV.delete("AI_MAX_OUTPUT_TOKENS")
    assert_nil @client.send(:max_output_tokens)

    ENV["AI_MAX_OUTPUT_TOKENS"] = "2048"
    assert_equal 2048, @client.send(:max_output_tokens)

    ENV["AI_MAX_OUTPUT_TOKENS"] = "0"
    assert_nil @client.send(:max_output_tokens)
  end

  test "ollama skips json_object response_format by default" do
    clear_provider_env!
    ENV["OLLAMA_API_KEY"] = "ollama-cloud-test-key"

    assert_not @client.send(:json_object_format?)

    ENV["AI_JSON_OBJECT"] = "on"
    assert @client.send(:json_object_format?)
  end

  test "openai keeps json_object response_format by default" do
    clear_provider_env!
    ENV["OPENAI_API_KEY"] = "sk-proj-test"

    assert @client.send(:json_object_format?)

    ENV["AI_JSON_OBJECT"] = "off"
    assert_not @client.send(:json_object_format?)
  end
end
