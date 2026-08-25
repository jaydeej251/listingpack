class GenerateCalendarJob < ApplicationJob
  queue_as :default

  def perform(calendar_id, consume_quota = true)
    calendar = WeeklyCalendar.find(calendar_id)
    calendar.update!(status: "generating")
    result = Ai::WriteCalendar.new(calendar).call
    calendar.update!(
      posts: result[:posts],
      status: "ready",
      error_message: nil
    )
  rescue StandardError => e
    calendar&.update!(status: "failed", error_message: e.message)
    calendar&.user&.refund_pack_quota! if consume_quota
    raise
  end
end
