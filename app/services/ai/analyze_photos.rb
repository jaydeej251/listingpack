module Ai
  class AnalyzePhotos
    def initialize(listing)
      @listing = listing
      @client = Ai::Client.new
    end

    def call
      return disabled_result unless PhotoVision.enabled?
      return { text: nil, model: "none", input_tokens: nil, output_tokens: nil } unless @client.configured?
      return { text: nil, model: "none", input_tokens: nil, output_tokens: nil } unless @listing.photos.attached?

      blob = @listing.photos.first.blob
      data_uri = @client.data_uri_for(blob)
      return { text: nil, model: "error", input_tokens: nil, output_tokens: nil, error: "Listing photo is missing from storage" } if data_uri.blank?
      result = @client.chat(
        messages: [
          { role: "system", content: "Describe listing photos for a Philippine real-estate agent. JSON with key photo_notes. Mention rooms, finishes, view, parking if visible. No hype words." },
          { role: "user", content: "{\"task\":\"describe_listing_photos\"}" }
        ],
        image_urls: [ data_uri ]
      )
      parsed = Ai::JsonResponse.parse(result[:text])
      notes = parsed.is_a?(Hash) ? (parsed["photo_notes"] || result[:text]) : result[:text]
      result.merge(text: notes)
    rescue ActiveStorage::FileNotFoundError => e
      { text: nil, model: "error", input_tokens: nil, output_tokens: nil, error: e.message }
    rescue Ai::Client::Error, JSON::ParserError => e
      { text: nil, model: "error", input_tokens: nil, output_tokens: nil, error: e.message }
    end

    private
      def disabled_result
        { text: nil, model: "disabled", input_tokens: nil, output_tokens: nil }
      end
  end
end
