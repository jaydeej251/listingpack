module Ai
  # Best-effort parse of model text into a Hash/Array.
  # Handles empty bodies, markdown fences, and leading prose before the first JSON object.
  class JsonResponse
    def self.parse(text)
      raw = text.to_s.strip
      raise JSON::ParserError, "unexpected end of input" if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      fenced = raw[/\A```(?:json)?\s*([\s\S]*?)```/i, 1]
      candidate = fenced.presence || extract_balanced_json(raw)
      raise JSON::ParserError, "unexpected end of input" if candidate.blank?

      JSON.parse(candidate)
    end

    def self.extract_balanced_json(text)
      start = text.index("{") || text.index("[")
      return nil unless start

      opener = text[start]
      closer = opener == "{" ? "}" : "]"
      depth = 0
      in_string = false
      escape = false

      text[start..].chars.each_with_index do |ch, i|
        if in_string
          if escape
            escape = false
          elsif ch == "\\"
            escape = true
          elsif ch == "\""
            in_string = false
          end
          next
        end

        case ch
        when "\"" then in_string = true
        when opener then depth += 1
        when closer
          depth -= 1
          return text[start, i + 1] if depth.zero?
        end
      end

      nil
    end
    private_class_method :extract_balanced_json
  end
end
