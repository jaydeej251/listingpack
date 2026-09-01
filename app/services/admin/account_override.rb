module Admin
  class AccountOverride
    class Error < StandardError; end

    def initialize(actor:, user:, reason:)
      @actor = actor
      @user = user
      @reason = reason.to_s.strip
    end

    def grant_pro!
      ensure_reason!
      raise Error, "Already on Pro." if @user.pro?

      previous = snapshot
      @user.update!(plan: "pro")
      record!("grant_pro", previous)
    end

    def revert_free!
      ensure_reason!
      raise Error, "Already on Free." if @user.free?

      previous = snapshot
      @user.update!(plan: "free")
      record!("revert_free", previous)
    end

    def reset_quota!
      ensure_reason!

      previous = snapshot
      @user.update!(
        quota_period_start: Time.zone.today.beginning_of_month,
        packs_count_in_period: 0
      )
      record!("reset_quota", previous)
    end

    private
      def ensure_reason!
        raise Error, "Reason is required." if @reason.length < 3
      end

      def snapshot
        {
          "plan" => @user.plan,
          "packs_count_in_period" => @user.packs_count_in_period,
          "quota_period_start" => @user.quota_period_start
        }
      end

      def record!(event_type, previous)
        BillingEvent.create!(
          provider: "admin",
          event_id: "admin-#{event_type}-#{@user.id}-#{SecureRandom.uuid}",
          event_type: event_type,
          user: @user,
          payload: {
            "actor_id" => @actor.id,
            "actor_email" => @actor.email_address,
            "reason" => @reason,
            "previous" => previous,
            "after" => snapshot
          },
          processed_at: Time.current
        )
      end
  end
end
