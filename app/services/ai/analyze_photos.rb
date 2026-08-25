module Ai
  class AnalyzePhotos
    def initialize(listing)
      @listing = listing
      @client = Ai::Client.new
    end

    def call
      return { text: nil, model: "none", input_tokens: nil, output_tokens: nil } unless @client.configured?
      return { text: nil, model: "none", input_tokens: nil, output_tokens: nil } unless @listing.photos.attached?

      blob = @listing.photos.first.blob
      result = @client.chat(
        messages: [
          { role: "system", content: "Describe listing photos for a Philippine real-estate agent. JSON with key photo_notes. Mention rooms, finishes, view, parking if visible. No hype words." },
          { role: "user", content: "{\"task\":\"describe_listing_photos\"}" }
        ],
        image_urls: [ @client.data_uri_for(blob) ]
      )
      notes = JSON.parse(result[:text]).fetch("photo_notes") { result[:text] }
      result.merge(text: notes)
    rescue Ai::Client::Error, JSON::ParserError => e
      { text: nil, model: "error", input_tokens: nil, output_tokens: nil, error: e.message }
    end
  end
end
