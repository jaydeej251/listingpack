module Images
  # Renders one or more posters, then always quits Chromium before returning.
  # Call with a single key for Free-tier 1-by-1; call with 3 keys for future Pro batch mode.
  class RenderPosterBatch
    def initialize(content_pack, template_keys)
      @pack = content_pack
      @listing = content_pack.listing
      @keys = Array(template_keys).map(&:to_s)
    end

    def call
      return { errors: [], rendered: 0 } if @keys.empty?

      watermark = @listing.user.free?
      photo_uri = Images::DataUri.from_attachment(@listing.photos.first)
      logo_uri = Images::DataUri.from_attachment(@listing.user.brand_kit&.logo)
      headshot_uri = Images::DataUri.from_attachment(@listing.user.brand_kit&.headshot)
      errors = []

      @keys.each do |key|
        asset = @pack.generated_assets.find_or_create_by!(template_key: key)
        asset.update!(status: "rendering", error_message: nil)
      end

      browser = nil
      begin
        begin
          browser = Images::PosterBrowser.open if Images::Chrome.path
        rescue Images::PosterBrowser::Error => e
          # Startup failure (common on Free when Chrome is slow) — fail this batch, let the chain continue.
          fail_all!(e.message)
          return { errors: @keys.map { |key| "#{key}: #{e.message}" }, rendered: 0 }
        end

        unless browser
          fail_all!("Google Chrome was not found")
          return { errors: @keys.map { |key| "#{key}: Google Chrome was not found" }, rendered: 0 }
        end

        @keys.each do |key|
          asset = @pack.generated_assets.find_by!(template_key: key)
          begin
            Images::RenderTemplate.new(
              @pack,
              key,
              watermark: watermark,
              photo_uri: photo_uri,
              logo_uri: logo_uri,
              headshot_uri: headshot_uri,
              browser: browser
            ).call
            asset.reload
            asset.update!(status: "ready", error_message: nil)
          rescue Images::RenderTemplate::Error, Images::PosterBrowser::Error => e
            errors << "#{key}: #{e.message}"
            asset.update!(status: "failed", error_message: e.message)
            @pack.generations.create!(
              kind: "image_#{key}",
              prompt_version: ::Prompts::ListingPack::VERSION,
              model: "ferrum",
              error_message: e.message
            )
          ensure
            GC.start
          end
        end
      ensure
        begin
          browser&.quit
        rescue StandardError
          nil
        end
        browser = nil
        GC.start
      end

      { errors: errors, rendered: @keys.size - errors.size }
    end

    private
      def fail_all!(message)
        @keys.each do |key|
          asset = @pack.generated_assets.find_by(template_key: key)
          next unless asset

          asset.update!(status: "failed", error_message: message)
          @pack.generations.create!(
            kind: "image_#{key}",
            prompt_version: ::Prompts::ListingPack::VERSION,
            model: "ferrum",
            error_message: message
          )
        end
      end
  end
end
