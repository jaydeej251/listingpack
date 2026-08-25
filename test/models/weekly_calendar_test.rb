require "test_helper"

class WeeklyCalendarTest < ActiveSupport::TestCase
  test "status label is human, not the raw enum" do
    calendar = WeeklyCalendar.new(status: "ready", week_start: Date.new(2026, 8, 24), focus_area: "BGC")
    assert_equal "Ready", calendar.status_label
    calendar.status = "generating"
    assert_equal "Generating", calendar.status_label
  end
end
