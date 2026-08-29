class RenderPosterBatchJob < ApplicationJob
  queue_as :default

  # Pause between posters so memory can be reclaimed between renders.
  NEXT_POSTER_WAIT = ENV.fetch("POSTER_NEXT_WAIT_SECONDS", "3").to_i.seconds

  def perform(content_pack_id, batch_index = 0)
    pack = ContentPack.find(content_pack_id)
    unless Images::PosterRender.enabled?
      Images::PosterRender.disable_pack!(pack)
      return
    end

    batches = GeneratedAsset.batches(user: pack.listing.user)
    keys = batches[batch_index]
    return if keys.blank?

    # Strict 1-by-1: one template per job.
    key = keys.first
    Images::RenderPosterBatch.new(pack, [ key ]).call
    Packs::UpdatePosterWarning.call(pack.reload)

    enqueue_next!(content_pack_id, pack, batches, batch_index)
  end

  private
    def enqueue_next!(content_pack_id, pack, batches, batch_index)
      next_index = batch_index + 1
      next_keys = batches[next_index]
      return if next_keys.blank?

      next_key = next_keys.first
      pack.generated_assets.where(template_key: next_key).update_all(status: "rendering", updated_at: Time.current)
      Packs::UpdatePosterWarning.call(pack)

      # Next format starts after a short pause.
      self.class.set(wait: NEXT_POSTER_WAIT).perform_later(content_pack_id, next_index)
    end
end
