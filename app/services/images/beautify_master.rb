require "stringio"
require "vips"

module Images
  # One OpenAI Images edit per pack → attach beauty_master; compositor falls back to listing photos.
  class BeautifyMaster
    VERSION = Images::BeautyPrompt::VERSION
    MAX_SIDE = 1536

    def initialize(content_pack, client: nil)
      @pack = content_pack
      @listing = content_pack.listing
      @client = client || Ai::ImageClient.new
    end

    def call
      return skip_result("already attached") if @pack.beauty_master.attached?
      return skip_result("disabled or no OpenAI image key") unless @client.enabled?
      return skip_result("no listing photos") unless @listing.photos.attached?

      prompt = Images::BeautyPrompt.new(listing: @listing).call
      images = reference_images
      return skip_result("could not prepare reference images") if images.empty?

      result = @client.edit(images: images, prompt: prompt)
      @pack.beauty_master.attach(
        io: StringIO.new(result[:png_bytes]),
        filename: "beauty_master.png",
        content_type: "image/png",
        identify: false
      )

      @pack.generations.create!(
        kind: "image_beauty",
        prompt_version: VERSION,
        model: result[:model],
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens]
      )

      { ok: true, model: result[:model], photos_used: images.size }
    rescue Ai::ImageClient::Error, Vips::Error, StandardError => e
      @pack.generations.create!(
        kind: "image_beauty",
        prompt_version: VERSION,
        model: @client.model,
        error_message: e.message.to_s.truncate(500)
      )
      { ok: false, error: e.message }
    end

    private
      def skip_result(reason)
        { ok: false, skipped: true, error: reason }
      end

      def reference_images
        max = @client.max_photos
        @listing.photos.attachments.first(max).filter_map.with_index do |attachment, index|
          bytes = png_bytes_for(attachment.blob)
          next if bytes.blank?

          {
            filename: "photo_#{index + 1}.png",
            content_type: "image/png",
            bytes: bytes
          }
        end
      end

      def png_bytes_for(blob)
        raw = blob.download
        image = Vips::Image.thumbnail_buffer(raw, MAX_SIDE, size: :down)
        image = image.flatten(background: [ 255, 255, 255 ]) if image.bands >= 4
        image.write_to_buffer(".png")
      rescue Vips::Error, ActiveStorage::FileNotFoundError, StandardError
        # Last resort: send original bytes if already png/jpeg under limit.
        raw = blob.download rescue nil
        return nil if raw.blank? || raw.bytesize > 15.megabytes

        raw
      end
  end
end
