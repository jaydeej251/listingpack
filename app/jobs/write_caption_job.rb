class WriteCaptionJob < ApplicationJob
  queue_as :default

  def perform(content_pack, field)
    raise ArgumentError, "unknown field" unless ContentPack::CAPTION_FIELDS.include?(field)

    listing = content_pack.listing
    copy = Ai::WritePack.new(listing: listing).call
    content_pack.update!(field => copy[field.to_sym])
    content_pack.generations.create!(
      kind: "caption_#{field}",
      prompt_version: copy[:prompt_version] || ::Prompts::ListingPack::VERSION,
      model: copy[:model],
      input_tokens: copy[:input_tokens],
      output_tokens: copy[:output_tokens]
    )
  end
end
