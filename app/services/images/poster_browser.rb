require "ferrum"

module Images
  class PosterBrowser
    class Error < StandardError; end

    OPTIONS = {
      "no-sandbox" => nil,
      "disable-gpu" => nil,
      "disable-dev-shm-usage" => nil,
      "disable-extensions" => nil,
      "disable-background-networking" => nil,
      "mute-audio" => nil,
      "js-flags" => "--max-old-space-size=96"
    }.freeze

    def self.open(window_size: [ 1080, 1080 ])
      raise Error, "Google Chrome was not found" unless Images::Chrome.path

      Ferrum::Browser.new(
        headless: true,
        browser_path: Images::Chrome.path,
        window_size: window_size,
        timeout: 25,
        process_timeout: 25,
        browser_options: OPTIONS
      )
    end
  end
end
