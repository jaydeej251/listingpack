module Packs
  class UpdatePosterWarning
    def self.call(pack)
      pack.update!(error_message: progress_message(pack))
    end

    def self.progress_message(pack)
      assets = pack.generated_assets.to_a
      return nil if assets.empty?

      failed = assets.select(&:failed?)
      pending = assets.select(&:in_progress?)
      ready = assets.count { |asset| asset.status == "ready" || asset.image.attached? }
      total = assets.size
      sequential = GeneratedAsset.render_mode(user: pack.listing.user) != "batch"

      if failed.size == total
        "Captions are ready, but every poster failed to render. #{failed.first&.error_message}. Use Redraw on each card."
      elsif failed.any? && pending.empty?
        "Captions are ready. Some posters failed: #{failed.map { |a| "#{a.template_key}: #{a.error_message}" }.join(' · ')}. Use Redraw on the missing ones."
      elsif pending.any?
        if sequential
          "Captions are ready. Posters stamp one at a time so this Free host stays under 512MB — #{ready} of #{total} ready."
        else
          "Captions are ready. Posters stamp in groups — #{ready} of #{total} ready."
        end
      end
    end
  end
end
