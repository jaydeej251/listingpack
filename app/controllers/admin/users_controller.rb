class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[ show grant_pro revert_free reset_quota ]

  def index
    scope = User.agents.order(created_at: :desc)
    if params[:q].present?
      query = "%#{User.sanitize_sql_like(params[:q].to_s.strip)}%"
      scope = scope.where("email_address ILIKE ?", query)
    end
    @users = scope.limit(50)
  end

  def show
    @billing_events = @user.billing_events.order(created_at: :desc).limit(20)
    @listings = @user.listings.includes(:content_packs).order(created_at: :desc).limit(20)
  end

  def grant_pro
    override.grant_pro!
    redirect_to admin_user_path(@user), notice: "Granted Pro. No PayMongo receipt was sent."
  rescue Admin::AccountOverride::Error => e
    redirect_to admin_user_path(@user), alert: e.message
  end

  def revert_free
    override.revert_free!
    redirect_to admin_user_path(@user), notice: "Reverted to Free."
  rescue Admin::AccountOverride::Error => e
    redirect_to admin_user_path(@user), alert: e.message
  end

  def reset_quota
    override.reset_quota!
    redirect_to admin_user_path(@user), notice: "Reset this month’s Free pack quota to 0 used."
  rescue Admin::AccountOverride::Error => e
    redirect_to admin_user_path(@user), alert: e.message
  end

  private
    def set_user
      @user = User.agents.find(params[:id])
    end

    def override
      Admin::AccountOverride.new(actor: Current.user, user: @user, reason: params[:reason])
    end
end
