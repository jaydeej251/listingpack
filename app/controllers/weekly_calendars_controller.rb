class WeeklyCalendarsController < ApplicationController
  before_action :require_agent!, only: %i[ index create ]
  before_action :set_calendar, only: %i[ show retry ]

  def index
    @calendars = Current.user.weekly_calendars.order(week_start: :desc)
    @calendar = @calendars.find { |item| item.week_start == Time.zone.today.beginning_of_week.to_date }
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: { status: @calendar.status } }
    end
  end

  def create
    week_start = Time.zone.today.beginning_of_week.to_date
    calendar = Current.user.weekly_calendars.find_or_initialize_by(week_start: week_start)

    if calendar.persisted? && calendar.generating?
      redirect_to calendar, alert: "This week is already generating."
      return
    end

    # New week or regenerating a ready week costs a credit. Failed weeks use #retry (free).
    if calendar.new_record? || calendar.ready?
      unless Current.user.consume_pack_quota!
        redirect_to billing_path, alert: "Free plan includes #{User::FREE_PACKS_PER_MONTH} packs this month."
        return
      end
      consume_quota = true
    else
      consume_quota = false
    end

    calendar.focus_area = calendar_params[:focus_area].presence || default_focus_area
    calendar.status = "generating"
    calendar.error_message = nil
    calendar.save!

    GenerateCalendarJob.perform_later(calendar.id, consume_quota)
    redirect_to calendar, notice: "Writing this week's posts…"
  end

  def retry
    if @calendar.generating?
      redirect_to @calendar, alert: "This week is already generating."
      return
    end

    @calendar.update!(status: "generating", error_message: nil)
    GenerateCalendarJob.perform_later(@calendar.id, false)
    redirect_to @calendar, notice: "Retrying this week…"
  end

  private
    def set_calendar
      @calendar =
        if Current.user.admin?
          WeeklyCalendar.find(params[:id])
        else
          Current.user.weekly_calendars.find(params[:id])
        end
    end

    def calendar_params
      params.fetch(:weekly_calendar, {}).permit(:focus_area)
    end

    def default_focus_area
      Current.user.listings.order(created_at: :desc).first&.location.presence || "Metro Manila"
    end
end
