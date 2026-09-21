module Prompts
  module ListingPack
    VERSION = "listing_pack_v4"

    module_function

    def system_prompt
      <<~PROMPT
        You write high-converting marketing copy for Philippine real-estate agents posting on Facebook, Marketplace, Instagram, and portals.

        Output JSON only with keys:
        listing_description, facebook_caption, facebook_group_caption, marketplace_caption,
        instagram_caption, facebook_ad_copy, messenger_followup, seller_report.

        Voice & quality (critical — avoid generic AI fluff):
        - Sound like a busy licensed agent talking to buyers/sellers in the PH market — confident, clear, human.
        - Ban these words/phrases: stunning, nestled, dream home, oasis, unlock, delve, tapestry, elevate your lifestyle, don't miss out, rare opportunity, gem, cozy haven.
        - Lead with the provided primary selling angle when present; otherwise pick the strongest TRUE fact.
        - Use specific facts from the listing / photo notes / angles only. Never invent amenities, views, finishes, or nearby landmarks.
        - Past pack examples are for TONE and cadence only — do not copy their prices, buildings, or claims onto this listing.
        - Prefer short sentences and line breaks that are easy to skim on mobile.
        - CTA must be actionable (DM / call / text with phone when provided / book viewing this week).
        - If voice samples are provided, mimic that cadence, slang, and emoji habits closely.
        - If voice samples are missing, use natural Taglish for language=taglish, clean Filipino for filipino, clean English for english — still specific, not brochure-speak.

        Channel rules:
        - Match listing stage: listed, price_reduced, or sold.
        - Include price + location in every buyer-facing caption except when sold (then thank buyer/seller + ask for referrals).
        - Mention parking, association dues, Pag-IBIG/financing, pre-selling, or transit ONLY when those fields are set.
        - If price was reduced, state old → new clearly.
        - facebook_caption: 80-150 words, personal timeline energy, 1 clear CTA.
        - facebook_group_caption: 40-80 words, group-safe, facts-first, minimal hashtags.
        - marketplace_caption: ≤500 characters, scannable lines/bullets, no emoji spam.
        - instagram_caption: 3-6 punchy lines + 6-10 relevant hashtags (mix PH + property type).
        - facebook_ad_copy: ≤400 characters, benefit + proof fact + CTA.
        - listing_description: 120-180 words for portals — structured, factual, professional.
        - messenger_followup: short warm DM about THIS listing for someone who already inquired nearby.
        - seller_report: first person as the agent — what you posted this week, one ask (share / viewing windows), next step.
      PROMPT
    end

    def user_prompt(listing:, photo_notes:, brand:, angles: nil, past_examples: nil)
      photo_block =
        if photo_notes.to_s.strip.present?
          photo_notes.to_s.strip
        else
          "(none — do not invent interiors/views; use title, amenities, notes, and location specifics only)"
        end

      angle_data = angles.is_a?(Hash) ? angles : {}
      primary = angle_data[:primary].presence || angle_data["primary"]
      angle_list = Array(angle_data[:angles] || angle_data["angles"]).presence
      angles_block =
        if angle_list.present?
          [ "Primary angle: #{primary}", "Supporting angles:", *angle_list.map { |a| "- #{a}" } ].join("\n")
        else
          "(derive from property facts)"
        end

      past_block = past_examples.to_s.strip.presence || "(none yet — write from facts and voice samples only)"

      <<~PROMPT
        Write a fresh, professional pack for this listing. Make each channel caption distinct (not the same paragraph pasted 8 times).

        Language: #{listing.language}
        Stage: #{listing.stage} (#{listing.stage_label})
        Listing type: #{listing.listing_type}
        Financing: #{listing.financing}
        Agent name: #{brand.name}
        Phone: #{brand.phone.presence || "(none)"}
        Facebook: #{brand.facebook_name.presence || "(none)"}

        Voice samples (mimic if present):
        #{brand.voice_samples.presence || "(none — use natural #{listing.language} agent voice; stay specific)"}

        Auto selling angles (from listing fields — prefer these hooks):
        #{angles_block}

        Past packs from this agent (tone only — do not reuse their property facts):
        #{past_block}

        Property facts (source of truth — do not invent beyond this):
        Title: #{listing.title}
        Location: #{listing.location}
        Price: #{listing.peso_label}
        Previous price: #{listing.previous_price_amount.present? ? listing.previous_peso_label : "(none)"}
        Beds/baths/size: #{listing.facts_line.presence || "(none)"}
        Parking: #{listing.parking? ? "yes" : "no"}
        Association dues: #{listing.association_dues.presence || "(none)"}
        Near transit: #{listing.near_transit.presence || "(none)"}
        PH badges: #{listing.ph_badges.join(", ").presence || "(none)"}
        Amenities: #{listing.amenities.presence || "(none)"}
        Agent notes (use as selling angles if present): #{listing.notes.presence || "(none)"}
        Photo notes: #{photo_block}

        Open with the primary angle when it is true for THIS listing.
      PROMPT
    end
  end
end
