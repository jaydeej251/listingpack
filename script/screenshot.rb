require "ferrum"
require "fileutils"

# Dev-only helper: screenshots the running app so UI changes can be reviewed.
# Usage: bin/rails runner script/screenshot.rb
raise "development only" unless Rails.env.development?

BASE = ENV.fetch("SHOT_BASE", "http://127.0.0.1:3000")
OUT = Rails.root.join("tmp/screenshots")
FileUtils.mkdir_p(OUT)

shots = [
  { name: "home-desktop", path: "/", size: [ 1440, 1200 ], full: true },
  { name: "home-mobile", path: "/", size: [ 390, 900 ], full: true },
  { name: "hero", path: "/", size: [ 1440, 1400 ], selector: ".surface-hero" },
  { name: "examples", path: "/", size: [ 1440, 2600 ], selector: "#how" },
  { name: "examples-mobile", path: "/", size: [ 390, 4400 ], selector: "#how" },
  { name: "hero-mobile", path: "/", size: [ 390, 1400 ], selector: ".surface-hero" }
]

browser = Ferrum::Browser.new(
  headless: true,
  browser_path: Images::Chrome.path,
  timeout: 30,
  process_timeout: 30,
  browser_options: { "no-sandbox" => nil, "disable-gpu" => nil, "force-color-profile" => "srgb" }
)

shots.each do |shot|
  browser.resize(width: shot[:size][0], height: shot[:size][1])
  browser.go_to("#{BASE}#{shot[:path]}")
  browser.network.wait_for_idle(timeout: 10) rescue nil
  sleep 1.2
  file = OUT.join("#{shot[:name]}.png")
  options = { path: file.to_s, format: "png" }
  if shot[:selector]
    options[:selector] = shot[:selector]
  else
    options[:full] = shot.fetch(:full, false)
  end
  browser.screenshot(**options)
  puts "wrote #{file} (#{File.size(file) / 1024}kb)"
end

browser.quit
