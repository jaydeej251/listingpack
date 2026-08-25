class RenderAssetJob < ApplicationJob
  queue_as :default

  def perform(content_pack, template_key)
    Images::RenderTemplate.new(
      content_pack,
      template_key,
      watermark: content_pack.listing.user.free?
    ).call
  end
end
