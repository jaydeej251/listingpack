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

    watermark = listing.user.free?
    poster_errors = []
    photo_uri = Images::DataUri.from_attachment(listing.photos.first)
    logo_uri = Images::DataUri.from_attachment(listing.user.brand_kit&.logo)
    headshot_uri = Images::DataUri.from_attachment(listing.user.brand_kit&.headshot)
    photo_missing = listing.photos.attached? && photo_uri.blank?
    GeneratedAsset::TEMPLATE_KEYS.each do |key|
      pack.generated_assets.find_or_create_by!(template_key: key)
      begin
        Images::RenderTemplate.new(
          pack,
          key,
          watermark: watermark,
          photo_uri: photo_uri,
          logo_uri: logo_uri,
          headshot_uri: headshot_uri
        ).call
      rescue Images::RenderTemplate::Error => e
        poster_errors << "#{key}: #{e.message}"
        pack.generations.create!(
          kind: "image_#{key}",
          prompt_version: ::Prompts::ListingPack::VERSION,
          model: "ferrum",
          error_message: e.message
        )
      end
    end

    poster_message =
      if poster_errors.size == GeneratedAsset::TEMPLATE_KEYS.size
        "Captions are ready, but every poster failed to render. #{poster_errors.first}. Use Redraw or try again on a host with more RAM for Chrome."
      elsif poster_errors.any?
        "Captions are ready. Some posters failed: #{poster_errors.join(' · ')}. Use Redraw on the missing ones."
      end
    if photo_missing
      poster_message = [
        poster_message,
        "The listing photo is missing from storage (common after an R2 checksum error or a Render disk wipe). The object in R2 may be from an earlier failed upload with a different key. Re-upload the photo, then Redraw."
      ].compact.join(" ")
    end

    pack.update!(status: "ready", error_message: poster_message)
    listing.update!(status: "ready")
  rescue Ai::Client::Error
    raise
  rescue StandardError => e
    pack&.update!(status: "failed", error_message: e.message)
    listing&.update!(status: "failed")
    pack&.generations&.create!(kind: "pack", error_message: e.message, prompt_version: ::Prompts::ListingPack::VERSION, model: "error")
    listing&.user&.refund_pack_quota! if consume_quota
    raise
  end
end
