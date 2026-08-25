module Ai
  class WritePack
    COPY_KEYS = ContentPack::CAPTION_FIELDS.map(&:to_sym).freeze

    def initialize(listing:, photo_notes: nil)
      @listing = listing
      @photo_notes = photo_notes
      @brand = listing.user.brand_kit
      @client = Ai::Client.new
    end

    def call
      if @client.configured?
        from_openai
      else
        from_template.merge(model: "template_fallback", prompt_version: ::Prompts::ListingPack::VERSION)
      end
    end

    private
      def from_openai
        result = @client.chat(
          messages: [
            { role: "system", content: ::Prompts::ListingPack.system_prompt },
            { role: "user", content: ::Prompts::ListingPack.user_prompt(listing: @listing, photo_notes: @photo_notes, brand: @brand) }
          ]
        )
        copy = JSON.parse(result[:text])
        COPY_KEYS.index_with { |key| copy[key.to_s] }.merge(
          model: result[:model],
          input_tokens: result[:input_tokens],
          output_tokens: result[:output_tokens],
          prompt_version: ::Prompts::ListingPack::VERSION
        )
      end

      def from_template
        name = @brand.name
        loc = @listing.location
        price = @listing.peso_label
        facts = @listing.facts_line
        badges = @listing.ph_badges
        cta = [ @brand.phone.presence && "Call/text #{@brand.phone}", "DM #{name}" ].compact.join(" or ")
        extras = [ badges.join(". "), @listing.amenities, @listing.notes, @photo_notes ].compact.reject(&:blank?).join(". ")
        extras_line = extras.present? ? "#{extras.truncate(220)} " : ""
        hook = hook_line(loc)

        {
          listing_description: description(hook, facts, price, extras_line, cta),
          facebook_caption: facebook(hook, facts, price, extras_line, cta),
          facebook_group_caption: group_caption(hook, facts, price, badges, cta),
          marketplace_caption: marketplace(facts, price, badges, cta),
          instagram_caption: instagram(hook, facts, price, loc, cta),
          facebook_ad_copy: "#{hook} #{facts} #{price}. #{badges.first}. Book a viewing. #{cta}.".truncate(400),
          messenger_followup: messenger(price, loc, cta),
          seller_report: seller_report(hook, price, cta)
        }
      end

      def hook_line(loc)
        case [ @listing.language, @listing.stage ]
        in [ "filipino", "price_reduced" ]
          "Bumaba ang presyo sa #{loc}."
        in [ "filipino", "sold" ]
          "Sold na po ang listing sa #{loc}."
        in [ "filipino", _ ]
          "Bagong listing sa #{loc}."
        in [ "english", "price_reduced" ]
          "Price drop in #{loc}."
        in [ "english", "sold" ]
          "Sold in #{loc}."
        in [ "english", _ ]
          "Just listed in #{loc}."
        in [ _, "price_reduced" ]
          "Price reduced sa #{loc} — #{@listing.title}."
        in [ _, "sold" ]
          "SOLD — #{@listing.title} sa #{loc}."
        else
          "Just listed sa #{loc} — #{@listing.title}."
        end
      end

      def description(hook, facts, price, extras_line, cta)
        reduced = @listing.stage == "price_reduced" && @listing.previous_price_amount.present? ? "Was #{@listing.previous_peso_label}, now #{price}. " : ""
        <<~TEXT.squish
          #{hook} #{facts.present? ? "#{facts}." : ""} #{reduced}Asking #{price}.
          #{extras_line}#{cta_or_sold(cta)}
        TEXT
      end

      def facebook(hook, facts, price, extras_line, cta)
        reduced = @listing.stage == "price_reduced" && @listing.previous_price_amount.present? ? "Was #{@listing.previous_peso_label} → now #{price}." : price
        <<~TEXT.strip
          #{hook}

          #{facts.present? ? facts : @listing.title}
          #{reduced}

          #{extras_line.presence || "Ready for viewing this week."}
          #{cta_or_sold(cta)}
        TEXT
      end

      def group_caption(hook, facts, price, badges, cta)
        <<~TEXT.squish
          #{hook} #{facts} #{price}.
          #{badges.join(" · ")}
          #{cta_or_sold(cta)}
        TEXT
      end

      def marketplace(facts, price, badges, cta)
        <<~TEXT.strip
          #{@listing.title} — #{@listing.location}
          #{price}#{@listing.stage == "price_reduced" && @listing.previous_price_amount.present? ? " (was #{@listing.previous_peso_label})" : ""}
          #{facts}
          #{badges.join("\n")}
          #{@listing.notes}
          #{cta_or_sold(cta)}
        TEXT
      end

      def instagram(hook, facts, price, loc, cta)
        <<~TEXT.strip
          #{hook}
          #{facts}
          #{price}
          #{cta_or_sold(cta)}

          ##{@listing.stage.camelize} #RealEstatePH #{loc.to_s.gsub(/\s+/, "")} #CondoPH #ListingPack
        TEXT
      end

      def messenger(price, loc, cta)
        if @listing.stage == "sold"
          "Hi! Sharing that #{@listing.title} in #{loc} is already sold. If you're still looking nearby, I can send similar options this week."
        else
          "Hi! You asked about #{loc} before. This #{@listing.title} is #{price}. #{@listing.parking? ? "Parking included. " : ""}Want a viewing sked this week? #{cta}"
        end
      end

      def seller_report(hook, price, cta)
        <<~TEXT.strip
          Hi — quick update on #{@listing.title} (#{@listing.location}).

          This week I published a #{@listing.stage_label.downcase} pack:
          • Facebook post, Facebook group post, Marketplace blurb, and Instagram caption
          • 3 branded posters (feed graphic, price card, agent card)
          • Asking #{price}#{@listing.parking? ? ", parking included" : ""}

          Next: please share the Facebook post to your own timeline/friends in the area, and send me 2 windows for viewing this week.

          I'll send another recap next week. #{cta}
        TEXT
      end

      def cta_or_sold(cta)
        @listing.stage == "sold" ? "Thank you to the buyer and seller — referrals welcome." : "Viewing by appointment. #{cta}."
      end
  end
end
