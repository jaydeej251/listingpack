class CaptionsController < ApplicationController
  before_action :set_pack

  def update
    field = params[:id]
    unless ContentPack::CAPTION_FIELDS.include?(field)
      redirect_to @pack.listing, alert: "Unknown caption."
      return
    end

    if params[:content_pack] && params[:content_pack][field]
      @pack.update!(field => params[:content_pack][field])
      redirect_to @pack.listing, notice: "Caption saved."
    else
      WriteCaptionJob.perform_now(@pack, field)
      redirect_to @pack.listing, notice: "Caption rewritten."
    end
  end

  private
    def set_pack
      listing = Current.user.listings.find(params[:listing_id])
      @pack = listing.content_packs.find(params[:content_pack_id])
    end
end
