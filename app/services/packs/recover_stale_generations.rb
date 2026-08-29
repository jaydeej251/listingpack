# When Solid Queue prunes a dead worker (OOM / hibernate / SIGKILL), Active Job
# never runs the job rescue — listings stay "generating" forever. Mark them failed
# so the UI can Retry. Ready packs can also be left with posters stuck on
# "rendering" after Chrome killed the dyno; unstick those too.
module Packs
  class RecoverStaleGenerations
    STALE_AFTER = 8.minutes
    MESSAGE =
      "Generation was interrupted (the job worker restarted or ran out of memory while rendering posters). Tap Retry — captions may already be saved."

    def self.call(stale_after: STALE_AFTER)
      new(stale_after: stale_after).call
    end

    def self.recover_listing_if_stale!(listing, stale_after: STALE_AFTER)
      return listing unless listing

      recover_stuck_posters!(listing, stale_after: stale_after)

      return listing unless listing.generating?
      return listing if listing.updated_at >= Time.current - stale_after

      new(stale_after: stale_after).recover_listing!(listing)
      listing.reload
    end

    def self.recover_stuck_posters!(listing, stale_after: STALE_AFTER)
      pack = listing&.latest_pack
      return listing if pack.blank?

      unless Images::PosterRender.enabled?
        Images::PosterRender.disable_pack!(pack)
        return listing
      end

      cutoff = Time.current - stale_after
      stuck = pack.generated_assets.select { |asset| asset.in_progress? && asset.updated_at <= cutoff }
      return listing if stuck.empty?

      stuck.each do |asset|
        asset.update!(status: "failed", error_message: Images::PosterRender::INTERRUPTED_MESSAGE)
      end
      Packs::UpdatePosterWarning.call(pack)
      listing
    end

    def initialize(stale_after: STALE_AFTER)
      @stale_after = stale_after
    end

    def call
      cutoff = Time.current - @stale_after
      recovered = 0

      Listing.where(status: "generating").where(updated_at: ...cutoff).find_each do |listing|
        recover_listing!(listing)
        recovered += 1
      end

      WeeklyCalendar.where(status: "generating").where(updated_at: ...cutoff).find_each do |calendar|
        calendar.update!(status: "failed", error_message: MESSAGE)
        recovered += 1
      end

      Listing.joins(content_packs: :generated_assets)
             .where(generated_assets: { status: %w[pending rendering] })
             .distinct
             .find_each do |listing|
        self.class.recover_stuck_posters!(listing, stale_after: @stale_after)
      end

      recovered
    end

    def recover_listing!(listing)
      pack = listing.latest_pack

      if pack&.ready?
        listing.update!(status: "ready")
        return listing
      end

      if pack.present? && pack.status != "failed"
        pack.update!(status: "failed", error_message: MESSAGE)
        pack.generations.create!(
          kind: "pack",
          error_message: MESSAGE,
          prompt_version: ::Prompts::ListingPack::VERSION,
          model: "stale_recovery"
        )
      end

      listing.update!(status: "failed")
      listing
    end
  end
end
