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
    @listing.update!(status: "generating")
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

    @listing.update!(status: "generating")
    GeneratePackJob.perform_later(@listing.id, pack.id, false)
    redirect_to @listing, notice: "Retrying generation…"
  end

  def status
    Packs::RecoverStaleGenerations.recover_listing_if_stale!(@listing)
    @pack = load_latest_pack
    respond_to do |format|
      format.html do
        assign_poster_vars
        render :status, layout: false
      end
      format.json do
        render json: poster_status_json(@pack)
      end
    end
  end

  def posters
    Packs::RecoverStaleGenerations.recover_listing_if_stale!(@listing)
    @pack = load_latest_pack

    unless turbo_frame_request?
      redirect_to listing_path(@listing)
      return
    end

    if @pack.blank?
      render html: helpers.turbo_frame_tag("listing_posters") {
        helpers.tag.p("No pack yet.", class: "mt-10 text-sm text-navy/70")
      }.html_safe, layout: false
      return
    end

    render partial: "listings/posters_section", locals: { listing: @listing, pack: @pack }, layout: false
  end

  private
    def set_listing
      @listing = Current.user.listings.find(params[:listing_id] || params[:id])
    end

    def load_latest_pack
      @listing.content_packs
              .includes(generated_assets: { image_attachment: :blob })
              .order(created_at: :desc)
              .first
    end

    def poster_status_json(pack)
      {
        status: @listing.pack_status,
        posters_complete: pack.blank? || pack.posters_complete?,
        ready_count: pack&.poster_ready_count || 0,
        total_count: pack&.poster_total_count || GeneratedAsset.display_keys(user: pack&.listing&.user).size,
        posters: pack&.poster_states || {}
      }
    end

    def assign_poster_vars
      @brand = @listing.user.brand_kit
      @photo_uri = @listing.photos.attached? ? url_for(@listing.photos.first) : nil
      @logo_uri = @brand&.logo&.attached? ? url_for(@brand.logo) : nil
      @headshot_uri = @brand&.headshot&.attached? ? url_for(@brand.headshot) : nil
      @watermark = current_user.free?
    end
end
