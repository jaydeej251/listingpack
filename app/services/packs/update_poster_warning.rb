module Packs
  class UpdatePosterWarning
    def self.call(pack)
      assets = pack.generated_assets.to_a
      failed = assets.select(&:failed?)
      pending = assets.select(&:in_progress?)
      ready = assets.select { |asset| asset.status == "ready" || asset.image.attached? }

      message =
        if assets.any? && failed.size == assets.size
          "Captions are ready, but every poster failed to render. #{failed.first&.error_message}. Use Redraw on each card."
        elsif failed.any? && pending.empty?
          "Captions are ready. Some posters failed: #{failed.map { |a| "#{a.template_key}: #{a.error_message}" }.join(' · ')}. Use Redraw on the missing ones."
        elsif pending.any?
          "Captions are ready. Posters stamp in groups of three so this host stays within Free memory — #{ready.size} of #{assets.size} ready."
        end

      pack.update!(error_message: message)
    end
  end
end
