module Images
  # Builds the OpenAI Images edit prompt for a 1:1 marketing master.
  class BeautyPrompt
    VERSION = "poster_beauty_v1"

    def initialize(listing:, brand: nil)
      @listing = listing
      @brand = brand || listing.user.brand_kit
    end

    def call
      support_count = [ @listing.photos.count - 1, 0 ].max
      support_note =
        if support_count.positive?
          "Images 2–#{[ support_count + 1, 6 ].min} are SUPPORT only (interiors/amenities for vibe). Do not collage them equally."
        else
          "Only one reference photo was provided — keep that property as the hero."
        end

      <<~PROMPT.strip
        Create a highly converting Philippine real-estate marketing material (social poster background).

        MASTER CANVAS: square 1:1, high resolution, designed so it can later be cropped to feed (1:1), Stories (9:16), and landscape (16:9).

        SAFE ZONE RULES (critical):
        - Keep the house/property, main visual focus, and any short headline inside the CENTER 60% of the frame.
        - Put only decorative foliage, sky, bokeh, or empty brand color in the outer 20% edges — those areas may be cropped away.
        - Leave clean negative space in the lower third and outer margins so we can stamp agent name, phone, price, and logo later.
        - Do NOT render phone numbers, URLs, fine legal text, or tiny logos — we add those exactly in post.

        REFERENCE PHOTOS:
        - Image 1 is the HERO: keep this building/unit recognizable as the main subject. Do not invent a different property.
        - #{support_note}

        STYLE:
        - Premium developer-style campaign look: polished, warm natural light, crisp, social-ready.
        - Brand accent color: #{@brand&.accent || "#C45C26"}. Brand ink/dark: #{@brand&.ink || "#14213D"}.
        - Mood matches listing stage: #{@listing.stage_banner}.

        PROPERTY DETAILS (reflect accurately; do not invent false amenities):
        - Title: #{@listing.title}
        - Location: #{@listing.location}
        - Price: #{@listing.peso_label}
        - Facts: #{@listing.facts_line.presence || "n/a"}
        - Stage: #{@listing.stage_label}
        - Type: #{Listing::LISTING_TYPES[@listing.listing_type]}
        - Badges: #{@listing.ph_badges.first(4).join(", ").presence || "none"}

        TEXT INSIDE IMAGE (keep short, large, high contrast — optional):
        - One short headline only (max 6 words), e.g. echoing "#{@listing.stage_banner}".
        - Optional tiny subline with location — nothing else.

        Output a single polished square marketing image ready for agent overlays.
      PROMPT
    end
  end
end
