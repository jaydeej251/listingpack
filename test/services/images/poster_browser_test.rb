require "test_helper"

class ImagesPosterBrowserTest < ActiveSupport::TestCase
  test "wraps Ferrum process timeout as PosterBrowser::Error" do
    previous = {
      "CHROME_START_ATTEMPTS" => ENV["CHROME_START_ATTEMPTS"],
      "CHROME_PROCESS_TIMEOUT" => ENV["CHROME_PROCESS_TIMEOUT"]
    }
    ENV["CHROME_START_ATTEMPTS"] = "1"
    ENV["CHROME_PROCESS_TIMEOUT"] = "90"

    stub_singleton(Images::Chrome, :path, "/usr/bin/chromium") do
      original = Ferrum::Browser.method(:new)
      Ferrum::Browser.define_singleton_method(:new) do |**|
        raise Ferrum::ProcessTimeoutError.new(25, "Browser did not produce websocket url")
      end

      error = assert_raises(Images::PosterBrowser::Error) { Images::PosterBrowser.open }
      assert_match(/too long to start/i, error.message)
    ensure
      Ferrum::Browser.define_singleton_method(:new, original) if defined?(original) && original
    end
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
