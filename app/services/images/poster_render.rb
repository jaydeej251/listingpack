module Images
  # Poster PNG rendering. Default is libvips (lightweight). Set POSTER_RENDERER=off to skip.
  class PosterRender
    INTERRUPTED_MESSAGE =
      "Poster rendering was interrupted (the server ran out of memory or restarted). Captions are saved."
    DISABLED_MESSAGE =
      "Poster PNGs are paused on this server. Set POSTER_RENDERER=vips to enable rendering."

    def self.renderer
      ENV.fetch("POSTER_RENDERER", "vips").downcase
    end

    def self.vips?
      renderer == "vips"
    end

    def self.enabled?
      !%w[off false none].include?(renderer)
    end

    def self.disable_pack!(pack)
      return pack if pack.blank?

      assets = pack.generated_assets.select(&:in_progress?)
      return pack if assets.empty?

      assets.each { |asset| fail_asset!(asset, disabled_message) }
      pack.reload.update!(error_message: disabled_message)
      pack
    end

    def self.fail_asset!(asset, message = disabled_message)
      asset.update!(status: "failed", error_message: message)
    end

    def self.disabled_message
      DISABLED_MESSAGE
    end
  end
end
