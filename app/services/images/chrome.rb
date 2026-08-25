module Images
  class Chrome
    CANDIDATES = [
      ENV["CHROME_PATH"],
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/usr/bin/google-chrome",
      "/usr/bin/google-chrome-stable",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser",
      "/usr/lib/chromium/chromium"
    ].compact.freeze

    def self.path
      CANDIDATES.find { |candidate| File.executable?(candidate) }
    end
  end
end
