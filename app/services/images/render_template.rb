require "ferrum"
require "fileutils"
require "stringio"

module Images
  class RenderTemplate
    class Error < StandardError; end

    def initialize(content_pack, template_key, watermark: false, photo_uri: :lookup, logo_uri: :lookup, headshot_uri: :lookup, browser: nil)
      @pack = content_pack
      @listing = content_pack.listing
      @brand = @listing.user.brand_kit
      @template_key = template_key
      @watermark = watermark
      @photo_uri = photo_uri == :lookup ? Images::DataUri.from_attachment(@listing.photos.first) : photo_uri
      @logo_uri = logo_uri == :lookup ? Images::DataUri.from_attachment(@brand&.logo) : logo_uri
      @headshot_uri = headshot_uri == :lookup ? Images::DataUri.from_attachment(@brand&.headshot) : headshot_uri
      @browser = browser
    end

    def call
      png_path = nil
      png_path = screenshot_html
      asset = @pack.generated_assets.find_or_initialize_by(template_key: @template_key)
      # Read into memory first — ActiveStorage can race with File.open + ensure delete.
      png_data = File.binread(png_path)
      asset.image.attach(
        io: StringIO.new(png_data),
        filename: "#{@template_key}.png",
        content_type: "image/png",
        identify: false
      )
      asset.save!
      asset
    ensure
      File.delete(png_path) if png_path && File.exist?(png_path)
    end

    private
      def screenshot_html
        html = ApplicationController.render(
          template: "packs/templates/#{@template_key}",
          layout: "poster",
          assigns: {
            listing: @listing,
            brand: @brand,
            pack: @pack,
            photo_uri: @photo_uri,
            logo_uri: @logo_uri,
            headshot_uri: @headshot_uri,
            watermark: @watermark
          }
        )

        dir = Rails.root.join("tmp/posters")
        FileUtils.mkdir_p(dir)
        html_path = dir.join("#{SecureRandom.uuid}.html")
        png_path = dir.join("#{SecureRandom.uuid}.png")
        File.write(html_path, html)

        width, height = GeneratedAsset.window_size(@template_key)
        owns_browser = @browser.nil?
        browser = @browser
        begin
          browser ||= Images::PosterBrowser.open(window_size: [ width, height ])
          browser.page.resize(width: width, height: height)
          browser.go_to("file://#{html_path}")
          browser.screenshot(path: png_path.to_s, selector: ".poster", format: "png")
          png_path.to_s
        rescue Images::PosterBrowser::Error => e
          raise Error, e.message
        rescue StandardError => e
          raise Error, e.message
        ensure
          browser&.quit if owns_browser
          File.delete(html_path) if html_path && File.exist?(html_path)
        end
      end
  end
end
