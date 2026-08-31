class PublicListingsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    @listing = Listing.with_attached_photos.includes(:content_packs, user: :brand_kit).find_by!(share_token: params[:share_token])
    @brand = @listing.user.brand_kit
    @pack = @listing.latest_pack
  end
end
