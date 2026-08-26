class GeneratePackJob < ApplicationJob
  queue_as :default

  # Reuse the same pack row across retries. Refund Free credit only when retries are exhausted.
  retry_on Ai::Client::Error, wait: :polynomially_longer, attempts: 3 do |job, error|
    listing_id, content_pack_id, consume_quota = job.arguments
    consume_quota = true if consume_quota.nil?
    listing = Listing.find_by(id: listing_id)
    pack = content_pack_id.present? ? listing&.content_packs&.find_by(id: content_pack_id) : listing&.latest_pack
    pack&.update!(status: "failed", error_message: error.message)
    listing&.update!(status: "failed")
    pack&.generations&.create!(kind: "pack", error_message: error.message, prompt_version: ::Prompts::ListingPack::VERSION, model: "error")
    listing&.user&.refund_pack_quota! if consume_quota
  end

  def perform(listing_id, content_pack_id = nil, consume_quota = true)
    listing = Listing.find(listing_id)
    pack = content_pack_id.present? ? listing.content_packs.find(content_pack_id) : nil
    pack ||= listing.content_packs.create!(language: listing.language, status: "generating", stage: listing.stage)

    listing.update!(status: "generating")
    pack.update!(status: "generating", error_message: nil)

    photo_result = Ai::AnalyzePhotos.new(listing).call
    copy = Ai::WritePack.new(listing: listing, photo_notes: photo_result[:text]).call

    pack.update!(copy.slice(*Ai::WritePack::COPY_KEYS).merge(language: listing.language, stage: listing.stage))

    pack.generations.create!(
      kind: "copy",
      prompt_version: copy[:prompt_version] || ::Prompts::ListingPack::VERSION,
      model: copy[:model],
      input_tokens: copy[:input_tokens],
      output_tokens: copy[:output_tokens],
      error_message: photo_result[:error]
    )

    ensure_poster_rows!(pack)
    first_keys = GeneratedAsset.batches(user: listing.user).first || []
    pack.generated_assets.where(template_key: first_keys).update_all(status: "rendering", updated_at: Time.current)

    pack.update!(
      status: "ready",
      error_message: Packs::UpdatePosterWarning.progress_message(pack)
    )
    listing.update!(status: "ready")

    # One poster (or one batch) per job so Chrome can fully exit before the next starts.
    RenderPosterBatchJob.perform_later(pack.id, 0)
  rescue Ai::Client::Error
    raise
  rescue StandardError => e
    pack&.update!(status: "failed", error_message: e.message) unless pack&.ready?
    listing&.update!(status: "failed") unless listing&.ready?
    pack&.generations&.create!(kind: "pack", error_message: e.message, prompt_version: ::Prompts::ListingPack::VERSION, model: "error")
    listing&.user&.refund_pack_quota! if consume_quota && !pack&.ready?
    raise
  end

  private
    def ensure_poster_rows!(pack)
      GeneratedAsset.generation_keys.each do |key|
        asset = pack.generated_assets.find_or_create_by!(template_key: key)
        asset.update!(status: "pending", error_message: nil)
      end
    end
end
