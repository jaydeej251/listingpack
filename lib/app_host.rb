# Canonical public hostname from env. Used by mailer URLs, host authorization,
# PayMongo return URLs, and OpenRouter referer headers.
module AppHost
  module_function

  def host(default: "localhost:3000")
    normalize(ENV["APP_HOST"].presence || default)
  end

  def allowed(default: "example.com")
    [ host(default: default), *aliases ].uniq
  end

  def origin(default: "localhost:3000")
    value = host(default: default)
    return value if value.match?(/\Ahttps?:\/\//i)

    local?(value) ? "http://#{value}" : "https://#{value}"
  end

  def aliases
    ENV.fetch("ADDITIONAL_HOSTS", "").split(",").map { |entry| normalize(entry) }.reject(&:blank?)
  end

  def normalize(value)
    value.to_s.strip.sub(%r{\Ahttps?://}i, "").split("/").first.to_s
  end

  def local?(value = host)
    value.match?(/\A(localhost|127\.0\.0\.1)(:\d+)?\z/i)
  end
end
