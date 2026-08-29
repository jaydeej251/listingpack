require "ferrum"

module Images
  class PosterBrowser
    class Error < StandardError; end

    # Render Free is CPU-throttled; Chromium often needs >25s to print a WS URL.
    OPTIONS = {
      "no-sandbox" => nil,
      "disable-gpu" => nil,
      "disable-dev-shm-usage" => nil,
      "disable-extensions" => nil,
      "disable-background-networking" => nil,
      "disable-default-apps" => nil,
      "disable-sync" => nil,
      "disable-translate" => nil,
      "hide-scrollbars" => nil,
      "metrics-recording-only" => nil,
      "mute-audio" => nil,
      "no-first-run" => nil,
      "js-flags" => "--max-old-space-size=96"
    }.freeze

    def self.process_timeout
      ENV.fetch("CHROME_PROCESS_TIMEOUT", "90").to_i
    end

    def self.command_timeout
      ENV.fetch("CHROME_TIMEOUT", "60").to_i
    end

    def self.start_attempts
      ENV.fetch("CHROME_START_ATTEMPTS", "2").to_i
    end

    def self.open(window_size: [ 1080, 1080 ])
      raise Error, Images::PosterRender::DISABLED_MESSAGE unless Images::PosterRender.enabled?
      raise Error, "Google Chrome was not found" unless Images::Chrome.path

      attempts = 0
      begin
        attempts += 1
        Ferrum::Browser.new(
          headless: true,
          browser_path: Images::Chrome.path,
          window_size: window_size,
          timeout: command_timeout,
          process_timeout: process_timeout,
          browser_options: OPTIONS
        )
      rescue Ferrum::ProcessTimeoutError => e
        sleep(1.5 * attempts) if attempts < start_attempts
        retry if attempts < start_attempts
        raise Error, "Chrome took too long to start (#{process_timeout}s). #{e.message}"
      rescue Ferrum::TimeoutError => e
        raise Error, "Chrome timed out. #{e.message}"
      rescue Ferrum::Error => e
        raise Error, e.message
      end
    end
  end
end
