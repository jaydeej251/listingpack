class Admin::FailuresController < Admin::BaseController
  def index
    @failed_listings = Listing.where(status: "failed").includes(:user, :content_packs).order(updated_at: :desc).limit(50)
    @failed_calendars = WeeklyCalendar.where(status: "failed").includes(:user).order(updated_at: :desc).limit(50)
    @poster_warnings = ContentPack.where(status: "ready").where.not(error_message: [ nil, "" ]).includes(listing: :user).order(updated_at: :desc).limit(50)
  end
end
