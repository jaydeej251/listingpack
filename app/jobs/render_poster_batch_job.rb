class RenderPosterBatchJob < ApplicationJob
  queue_as :default

  def perform(content_pack_id, batch_index = 0)
    pack = ContentPack.find(content_pack_id)
    batches = GeneratedAsset.batches
    keys = batches[batch_index]
    return if keys.blank?

    result = Images::RenderPosterBatch.new(pack, keys).call
    Packs::UpdatePosterWarning.call(pack)

    next_index = batch_index + 1
    if batches[next_index].present?
      pack.generated_assets.where(template_key: batches[next_index]).update_all(status: "rendering", updated_at: Time.current)
      Packs::UpdatePosterWarning.call(pack)
      self.class.perform_later(content_pack_id, next_index)
    end

    result
  end
end
