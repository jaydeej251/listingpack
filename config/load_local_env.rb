# Load gitignored `.env` in development so local Rails matches production env vars.
# Does not override variables already set (shell, process supervisor).
# Skips test: `bin/rails test` requires boot.rb *before* RAILS_ENV=test is set, so also
# detect the test command via ARGV. Live API keys must not leak into fallback tests.
# Skips production: the host injects env; never read a dotenv file there.
rails_env = ENV["RAILS_ENV"] || ENV["RACK_ENV"]
running_tests =
  rails_env == "test" ||
  ARGV.any? { |arg| arg == "test" || arg.start_with?("test:") || arg.start_with?("test/") }
return if rails_env == "production" || running_tests

env_file = File.expand_path("../.env", __dir__)
return unless File.exist?(env_file)

File.foreach(env_file) do |line|
  line = line.strip
  next if line.empty? || line.start_with?("#")

  line = line.sub(/\Aexport\s+/, "")
  key, eq, value = line.partition("=")
  next unless eq == "=" && key.match?(/\A[A-Z_][A-Z0-9_]*\z/)
  next unless ENV[key].to_s.empty?

  value = value.strip
  if value.length >= 2 && ((value.start_with?('"') && value.end_with?('"')) || (value.start_with?("'") && value.end_with?("'")))
    value = value[1..-2]
  end
  ENV[key] = value
end
