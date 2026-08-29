module Images
  # Renders one or more posters via libvips compositing.
  class RenderPosterBatch
    def initialize(content_pack, template_keys)
      @pack = content_pack
      @listing = content_pack.listing
      @keys = Array(template_keys).map(&:to_s)
    end

    def call
      return { errors: [], rendered: 0 } if @keys.empty?

      unless Images::PosterRender.enabled?
        fail_all!(Images::PosterRender.disabled_message)
        return { errors: @keys.map { |key| "#{key}: #{Images::PosterRender.disabled_message}" }, rendered: 0 }
      end

      watermark = @listing.user.free?
      errors = []

      @keys.each do |key|
        asset = @pack.generated_assets.find_or_create_by!(template_key: key)
        asset.update!(status: "rendering", error_message: nil)
      end

      @keys.each do |key|
        asset = @pack.generated_assets.find_by!(template_key: key)
        begin
          Images::ComposePoster.new(@pack, key, watermark: watermark).call
          asset.reload
          asset.update!(status: "ready", error_message: nil)
        rescue Images::ComposePoster::Error => e
          errors << "#{key}: #{e.message}"
          asset.update!(status: "failed", error_message: e.message)
          @pack.generations.create!(
            kind: "image_#{key}",
            prompt_version: ::Prompts::ListingPack::VERSION,
            model: "vips",
            error_message: e.message
          )
        ensure
          GC.start
        end
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
            model: "vips",
            error_message: message
          )
        end
      end
  end
end
