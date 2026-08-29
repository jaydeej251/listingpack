class RenderAssetJob < ApplicationJob
  queue_as :default

  def perform(content_pack_or_id, template_key)
    pack = content_pack_or_id.is_a?(ContentPack) ? content_pack_or_id : ContentPack.find(content_pack_or_id)
    unless Images::PosterRender.enabled?
      asset = pack.generated_assets.find_by(template_key: template_key)
      Images::PosterRender.fail_asset!(asset) if asset
      pack.reload.update!(error_message: Images::PosterRender::DISABLED_MESSAGE)
      return
    end

    Images::RenderPosterBatch.new(pack, [ template_key ]).call
    Packs::UpdatePosterWarning.call(pack)
  end
end
