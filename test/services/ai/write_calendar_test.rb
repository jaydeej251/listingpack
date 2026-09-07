require "test_helper"

class WriteCalendarTest < ActiveSupport::TestCase
  test "fallback calendar has five weekday posts" do
    without_env("OPENROUTER_API_KEY", "OPENAI_API_KEY", "OLLAMA_API_KEY") do
      calendar = WeeklyCalendar.new(user: users(:one), week_start: Date.new(2026, 8, 24), focus_area: "BGC", status: "pending")
      result = Ai::WriteCalendar.new(calendar).call

      assert_equal 5, result[:posts].length
      assert_equal "Monday", result[:posts].first["day"]
      assert_includes result[:posts].first["body"], "BGC"
    end
  end
end
