class BrandKitsController < ApplicationController
  before_action :set_brand_kit

  def edit
  end

  def update
    if @brand_kit.update(brand_kit_params)
      destination = Current.user.listings.exists? ? listings_path : new_listing_path
      redirect_to destination, notice: "Brand kit saved. New packs will use this voice and look."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_brand_kit
      @brand_kit = Current.user.brand_kit || Current.user.create_brand_kit!
    end

    def brand_kit_params
      params.require(:brand_kit).permit(
        :display_name, :phone, :facebook_name, :primary_color, :secondary_color, :voice_samples, :logo, :headshot
      )
    end
end
