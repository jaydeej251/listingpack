module Prompts
  module ListingPack
    VERSION = "listing_pack_v2"

    module_function

    def system_prompt
      <<~PROMPT
        You write marketing copy for Philippine real-estate agents.
        Output JSON only with keys:
        listing_description, facebook_caption, facebook_group_caption, marketplace_caption,
        instagram_caption, facebook_ad_copy, messenger_followup, seller_report.
        Rules:
        - Sound like a working agent, not a brochure factory. No "stunning", "nestled", "dream home".
        - Match the listing stage: listed, price_reduced, or sold.
        - Include price, location, and a clear CTA except for sold (sold should thank buyers/sellers and invite referrals).
        - Mention parking, association dues, Pag-IBIG, financing, pre-selling, or transit only when those fields are set.
        - If price was reduced, mention the old and new price.
        - Match the requested language (english, filipino, or taglish).
        - If voice samples are provided, mimic that cadence and word choice.
        - facebook_caption: 80-150 words for a personal Facebook profile.
        - facebook_group_caption: shorter, group-safe, 40-80 words, less hashtags, more facts.
        - marketplace_caption: 500 characters or less, scannable bullets, no emoji spam.
        - Instagram caption: 3-6 lines plus 6-10 hashtags.
        - Facebook ad copy: 400 characters or less.
        - listing_description: 120-180 words for portals.
        - messenger_followup: a short DM they can send to a warm lead about THIS listing.
        - seller_report: a one-page update the agent can send the seller this week (what was posted, next step, ask them to share). Write in first person as the agent.
      PROMPT
    end

    def user_prompt(listing:, photo_notes:, brand:)
      <<~PROMPT
        Language: #{listing.language}
        Stage: #{listing.stage} (#{listing.stage_label})
        Listing type: #{listing.listing_type}
        Financing: #{listing.financing}
        Agent name: #{brand.name}
        Phone: #{brand.phone}
        Facebook: #{brand.facebook_name}

        Voice samples:
        #{brand.voice_samples.presence || "(none — use natural Taglish unless another language is requested)"}

        Property:
        Title: #{listing.title}
        Location: #{listing.location}
        Price: #{listing.peso_label}
        Previous price: #{listing.previous_price_amount.present? ? listing.previous_peso_label : "(none)"}
        Beds/baths/size: #{listing.facts_line}
        Parking: #{listing.parking? ? "yes" : "no"}
        Association dues: #{listing.association_dues.presence || "(none)"}
        Near transit: #{listing.near_transit.presence || "(none)"}
        PH badges: #{listing.ph_badges.join(", ").presence || "(none)"}
        Amenities: #{listing.amenities}
        Agent notes: #{listing.notes}
        Photo notes: #{photo_notes.presence || "(none)"}
      PROMPT
    end
  end
end
