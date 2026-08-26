class ListingsController < ApplicationController
  before_action :set_listing, only: %i[ show edit update destroy seller_report ]

  def index
    @listings = Current.user.listings.with_attached_photos.includes(:content_packs).order(created_at: :desc)
  end

  def show
    Packs::RecoverStaleGenerations.recover_listing_if_stale!(@listing)
    @pack = @listing.latest_pack
    assign_poster_vars
  end

  def new
    @listing = Current.user.listings.new(language: "taglish", stage: "listed", listing_type: "for_sale", financing: "negotiable")
  end

  def create
    @listing = Current.user.listings.new(listing_params)
    if @listing.save
      start_generation(@listing)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @listing.update(listing_params)
      redirect_to @listing, notice: "Listing updated. Generate again to refresh copy and posters for this stage."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @listing.destroy
    redirect_to listings_path, notice: "Listing removed."
  end

  def seller_report
    @pack = @listing.latest_pack
    if @pack.blank? || @pack.seller_report.blank?
      redirect_to @listing, alert: "Generate a pack first — the seller report is part of it."
    end
  end

  private
    def set_listing
      @listing =
        if Current.user.admin?
          Listing.find(params[:id])
        else
          Current.user.listings.find(params[:id])
        end
    end

    def listing_params
      params.require(:listing).permit(
        :title, :location, :price_amount, :previous_price_amount, :bedrooms, :bathrooms, :floor_area,
        :amenities, :notes, :language, :stage, :listing_type, :financing, :association_dues,
        :near_transit, :parking, photos: []
      )
    end

    def assign_poster_vars
      @brand = @listing.user.brand_kit
      @photo_uri = @listing.photos.attached? ? url_for(@listing.photos.first) : nil
      @logo_uri = @brand&.logo&.attached? ? url_for(@brand.logo) : nil
      @headshot_uri = @brand&.headshot&.attached? ? url_for(@brand.headshot) : nil
      @watermark = current_user.free?
    end

    def start_generation(listing)
      unless Current.user.consume_pack_quota!
        redirect_to listing, alert: "Listing saved. Free plan includes #{User::FREE_PACKS_PER_MONTH} packs this month — upgrade on Plan to generate."
        return
      end

      listing.update!(status: "generating")
      GeneratePackJob.perform_later(listing.id)
      redirect_to listing, notice: "Generating captions, seller report, and branded posters…"
    end
end
