class RenderAssetJob < ApplicationJob
  queue_as :default

  def perform(content_pack_or_id, template_key)
    pack = content_pack_or_id.is_a?(ContentPack) ? content_pack_or_id : ContentPack.find(content_pack_or_id)
    Images::RenderPosterBatch.new(pack, [ template_key ]).call
    Packs::UpdatePosterWarning.call(pack)
  end
end
