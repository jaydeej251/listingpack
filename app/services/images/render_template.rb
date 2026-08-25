require "ferrum"
require "fileutils"
require "stringio"

module Images
  class RenderTemplate
    class Error < StandardError; end

    def initialize(content_pack, template_key, watermark: false)
      @pack = content_pack
      @listing = content_pack.listing
      @brand = @listing.user.brand_kit
      @template_key = template_key
      @watermark = watermark
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
        content_type: "image/png"
      )
      asset.save!
      asset
    ensure
      File.delete(png_path) if png_path && File.exist?(png_path)
    end

    private
      def screenshot_html
        raise Error, "Google Chrome was not found" unless Images::Chrome.path

        html = ApplicationController.render(
          template: "packs/templates/#{@template_key}",
          layout: "poster",
          assigns: {
            listing: @listing,
            brand: @brand,
            pack: @pack,
            photo_uri: Images::DataUri.from_attachment(@listing.photos.first),
            logo_uri: Images::DataUri.from_attachment(@brand&.logo),
            headshot_uri: Images::DataUri.from_attachment(@brand&.headshot),
            watermark: @watermark
          }
        )

        dir = Rails.root.join("tmp/posters")
        FileUtils.mkdir_p(dir)
        html_path = dir.join("#{SecureRandom.uuid}.html")
        png_path = dir.join("#{SecureRandom.uuid}.png")
        File.write(html_path, html)

        browser = nil
        browser = Ferrum::Browser.new(
          headless: true,
          browser_path: Images::Chrome.path,
          window_size: [ 1080, 1080 ],
          timeout: 20,
          process_timeout: 20,
          browser_options: {
            "no-sandbox" => nil,
            "disable-gpu" => nil
          }
        )
        browser.go_to("file://#{html_path}")
        browser.screenshot(path: png_path.to_s, selector: ".poster", format: "png")
        png_path.to_s
      rescue StandardError => e
        raise Error, e.message
      ensure
        browser&.quit
        File.delete(html_path) if defined?(html_path) && html_path && File.exist?(html_path)
      end
  end
end
