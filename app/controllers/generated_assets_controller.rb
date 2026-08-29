class GeneratedAssetsController < ApplicationController
  before_action :set_asset

  def regenerate
    unless Images::PosterRender.enabled?
      Images::PosterRender.fail_asset!(@asset)
      @asset.content_pack.update!(error_message: Images::PosterRender::DISABLED_MESSAGE)
      redirect_to @asset.content_pack.listing, alert: Images::PosterRender::DISABLED_MESSAGE
      return
    end

    @asset.update!(status: "rendering", error_message: nil)
    RenderAssetJob.perform_later(@asset.content_pack.id, @asset.template_key)
    redirect_to @asset.content_pack.listing, notice: "Redrawing that poster…"
  end

  private
    def set_asset
      listing = Current.user.listings.find(params[:listing_id])
      pack = listing.content_packs.find(params[:content_pack_id])
      @asset = pack.generated_assets.find(params[:id])
    end
end
