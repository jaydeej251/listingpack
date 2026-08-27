module Packs
  class UpdatePosterWarning
    def self.call(pack)
      pack.update!(error_message: failure_message(pack))
    end

    # Only persist failures. In-progress copy is rendered live from asset statuses.
    def self.failure_message(pack)
      assets = pack.generated_assets.to_a
      return nil if assets.empty?

      failed = assets.select(&:failed?)
      pending = assets.select(&:in_progress?)

      if failed.size == assets.size
        "We couldn’t create the posters. Tap Redraw on a card to try again."
      elsif failed.any? && pending.empty?
        labels = failed.map { |asset| GeneratedAsset.format_for(asset.template_key).fetch(:short) }
        "Some posters need a retry (#{labels.join(', ')}). Use Redraw on those cards."
      end
    end

    # Kept for GeneratePackJob callers that still reference the old name.
    def self.progress_message(pack)
      failure_message(pack)
    end
  end
end
