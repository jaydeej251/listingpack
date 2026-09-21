module Ai
  # Tier 1 enrichment: selling angles derived only from listing fields (no web/RAG).
  class ListingAngles
    MAX_ANGLES = 8

    def initialize(listing)
      @listing = listing
    end

    def call
      angles = []
      angles << stage_angle
      angles << "Agent note: #{@listing.notes.to_s.squish.truncate(120)}" if @listing.notes.present?
      angles << financing_angle
      angles << "Parking included" if @listing.parking?
      angles << "Near #{@listing.near_transit}" if @listing.near_transit.present?
      angles << "Assoc dues #{@listing.association_dues}" if @listing.association_dues.present?
      angles << type_angle
      angles << "Facts: #{@listing.facts_line}" if @listing.facts_line.present?
      angles << "Location focus: #{@listing.location}" if @listing.location.present?

      {
        primary: angles.compact.first,
        angles: angles.compact.first(MAX_ANGLES)
      }
    end

    private
      def stage_angle
        case @listing.stage
        when "price_reduced"
          if @listing.previous_price_amount.present?
            "Price reduced: was #{@listing.previous_peso_label} → now #{@listing.peso_label}"
          else
            "Price reduced — highlight the new ask #{@listing.peso_label}"
          end
        when "sold"
          "Sold — thank buyer/seller and ask for referrals"
        else
          "Just listed at #{@listing.peso_label}"
        end
      end

      def financing_angle
        return nil if @listing.financing.blank? || @listing.financing == "negotiable"

        label = Listing::FINANCING_OPTIONS[@listing.financing]
        "#{label} welcome" if label
      end

      def type_angle
        case @listing.listing_type
        when "for_rent" then "For rent — lead with monthly terms and viewing"
        when "pre_selling" then "Pre-selling — clarify timeline / turnover if in notes"
        else nil
        end
      end
  end
end
