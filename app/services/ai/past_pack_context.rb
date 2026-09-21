module Ai
  # Tier 2 enrichment: pull a few of this agent's past ready captions as style examples.
  # No embeddings — keyword overlap on location + stage/type match. Never invents unit facts.
  class PastPackContext
    MAX_EXAMPLES = 2
    CAPTION_LIMIT = 420

    def initialize(listing)
      @listing = listing
      @user = listing.user
    end

    def call
      examples = ranked_packs.first(MAX_EXAMPLES).filter_map { |pack| example_from(pack) }
      {
        examples: examples,
        prompt_block: format_block(examples)
      }
    end

    private
      def ranked_packs
        packs = ContentPack
          .joins(:listing)
          .where(listings: { user_id: @user.id }, status: "ready")
          .where.not(listing_id: @listing.id)
          .where.not(facebook_caption: [ nil, "" ])
          .includes(:listing)
          .order(updated_at: :desc)
          .limit(25)
          .to_a

        packs.sort_by { |pack| -score(pack) }
      end

      def score(pack)
        other = pack.listing
        points = 0
        points += 5 if other.stage == @listing.stage
        points += 3 if other.listing_type == @listing.listing_type
        points += 4 * location_overlap(other.location.to_s, @listing.location.to_s)
        points += 1 if other.language == @listing.language
        points
      end

      def location_overlap(a, b)
        tokens_a = normalize_tokens(a)
        tokens_b = normalize_tokens(b)
        return 0 if tokens_a.empty? || tokens_b.empty?

        (tokens_a & tokens_b).size
      end

      def normalize_tokens(text)
        text.downcase.scan(/[a-z0-9]+/).reject { |t| t.length < 3 || %w[the and for near].include?(t) }
      end

      def example_from(pack)
        caption = pack.facebook_caption.to_s.squish
        return nil if caption.blank?

        {
          location: pack.listing.location,
          stage: pack.listing.stage_label,
          facebook_caption: caption.truncate(CAPTION_LIMIT)
        }
      end

      def format_block(examples)
        return "(none yet — write from facts and voice samples only)" if examples.empty?

        examples.map.with_index(1) { |ex, i|
          <<~EX.strip
            Example #{i} (past pack · #{ex[:location]} · #{ex[:stage]} — mimic tone only, not facts):
            #{ex[:facebook_caption]}
          EX
        }.join("\n\n")
      end
  end
end
