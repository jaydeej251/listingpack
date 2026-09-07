require "test_helper"

class AiJsonResponseTest < ActiveSupport::TestCase
  test "parses plain json" do
    assert_equal({ "a" => 1 }, Ai::JsonResponse.parse('{"a":1}'))
  end

  test "parses fenced json" do
    text = "```json\n{\"photo_notes\":\"balcony\"}\n```"
    assert_equal({ "photo_notes" => "balcony" }, Ai::JsonResponse.parse(text))
  end

  test "extracts object after prose" do
    text = "Sure! Here you go:\n{\"facebook_caption\":\"Hi\"}"
    assert_equal({ "facebook_caption" => "Hi" }, Ai::JsonResponse.parse(text))
  end

  test "blank raises parser error" do
    assert_raises(JSON::ParserError) { Ai::JsonResponse.parse("") }
    assert_raises(JSON::ParserError) { Ai::JsonResponse.parse(nil) }
  end
end
