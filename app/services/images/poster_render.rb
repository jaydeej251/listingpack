module Images
  # Poster PNGs need Chromium. On Render Free (~512 MB) that OOM-kills Puma
  # (web + Solid Queue share one process) and the site returns 502.
  #
  # Default: render posters, except on Render.com where Chromium must be
  # opted in. Hatchbox / a sized droplet do not set RENDER, so posters stay on.
  #
  # POSTER_RENDER_ENABLED=true  — force Chrome (Render Starter+ or any host)
  # POSTER_RENDER_ENABLED=false — never start Chrome
  class PosterRender
    DISABLED_MESSAGE =
      "Poster PNGs are paused on this server so captions can finish. This host does not have enough memory for Chrome."

    INTERRUPTED_MESSAGE =
      "Poster rendering was interrupted (the server ran out of memory or restarted). Captions are saved."

    def self.enabled?
      flag = ENV["POSTER_RENDER_ENABLED"]
      return ActiveModel::Type::Boolean.new.cast(flag) if flag.present?

      ENV["RENDER"].blank?
    end

    def self.disable_pack!(pack)
      return pack if pack.blank?

      assets = pack.generated_assets.select(&:in_progress?)
      return pack if assets.empty?

      assets.each { |asset| fail_asset!(asset, DISABLED_MESSAGE) }
      pack.reload.update!(error_message: DISABLED_MESSAGE)
      pack
    end

    def self.fail_asset!(asset, message = DISABLED_MESSAGE)
      asset.update!(status: "failed", error_message: message)
    end
  end
end
