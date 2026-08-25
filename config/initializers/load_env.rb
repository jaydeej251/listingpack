# Rails 8 does not load `.env` by default. Keep secrets out of production
# (Render env vars) and tests (they must not pick up a developer key).
if Rails.env.development?
  path = Rails.root.join(".env")
  if path.exist?
    path.readlines(chomp: true).each do |line|
      next if line.blank? || line.start_with?("#")

      key, value = line.split("=", 2)
      next if key.blank? || value.nil?

      ENV[key.strip] ||= value.strip.gsub(/\A['"]|['"]\z/, "")
    end
  end
end
