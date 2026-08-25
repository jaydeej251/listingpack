class ContentPacksController < ApplicationController
  before_action :set_listing

  def create
    if @listing.generating?
      redirect_to @listing, alert: "This listing is already generating a pack."
      return
    end

    unless Current.user.consume_pack_quota!
      redirect_to billing_path, alert: "Free plan includes #{User::FREE_PACKS_PER_MONTH} packs this month."
      return
    end

    pack = @listing.content_packs.create!(language: @listing.language, status: "generating", stage: @listing.stage)
    @listing.update!(status: "generating", price_confirmed: false)
    GeneratePackJob.perform_later(@listing.id, pack.id, true)
    redirect_to @listing, notice: "Generating a new pack…"
  end

  def retry
    if @listing.generating?
      redirect_to @listing, alert: "This listing is already generating a pack."
      return
    end

    pack = @listing.latest_pack
    if pack.blank?
      pack = @listing.content_packs.create!(language: @listing.language, status: "generating", stage: @listing.stage)
    else
      pack.update!(status: "generating", error_message: nil, stage: @listing.stage)
    end

    @listing.update!(status: "generating", price_confirmed: false)
    GeneratePackJob.perform_later(@listing.id, pack.id, false)
    redirect_to @listing, notice: "Retrying generation…"
  end

  def status
    @pack = @listing.latest_pack
    assign_poster_vars
    render :status, layout: false
  end

  private
    def set_listing
      @listing = Current.user.listings.find(params[:listing_id] || params[:id])
    end

    def assign_poster_vars
      @brand = @listing.user.brand_kit
      @photo_uri = @listing.photos.attached? ? url_for(@listing.photos.first) : nil
      @logo_uri = @brand&.logo&.attached? ? url_for(@brand.logo) : nil
      @headshot_uri = @brand&.headshot&.attached? ? url_for(@brand.headshot) : nil
      @watermark = current_user.free?
    end
end
