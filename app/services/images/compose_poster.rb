require "stringio"

module Images
  class ComposePoster
    class Error < StandardError; end

    WHITE = [ 255, 255, 255 ].freeze
    CREAM = [ 243, 238, 228 ].freeze
    TITLE_LINE_HEIGHT = 1.28

    def initialize(content_pack, template_key, watermark: false)
      @pack = content_pack
      @listing = content_pack.listing
      @brand = @listing.user.brand_kit
      @key = template_key.to_s
      @watermark = watermark
    end

    def call
      width, height = GeneratedAsset.window_size(@key)
      png_data = render_layout(width, height)

      asset = @pack.generated_assets.find_or_initialize_by(template_key: @key)
      asset.image.attach(
        io: StringIO.new(png_data),
        filename: "#{@key}.png",
        content_type: "image/png",
        identify: false
      )
      asset.status = "ready"
      asset.error_message = nil
      asset.save!
      asset
    rescue Vips::Error, StandardError => e
      raise Error, e.message
    ensure
      release_memory!
      GC.start
    end

    private
      def render_layout(width, height)
        case @key
        when "just_listed" then render_just_listed(width, height)
        when "price_card" then render_price_card(width, height)
        when "agent_card" then render_agent_card(width, height)
        when "story" then render_story(width, height)
        when "landscape" then render_landscape(width, height)
        when "fb_banner" then render_fb_banner(width, height)
        else
          raise Error, "Unknown poster format: #{@key}"
        end
      end

      def accent_rgb
        PosterCanvas.parse_hex(@brand&.accent, fallback: [ 196, 92, 38 ])
      end

      def ink_rgb
        PosterCanvas.parse_hex(@brand&.ink, fallback: [ 20, 33, 61 ])
      end

      def photo_image
        @photo_image ||= PosterCanvas.load_attachment(@listing.photos.first, max_side: photo_max_side)
      end

      def logo_image
        @logo_image ||= PosterCanvas.load_attachment(@brand&.logo, max_side: 512)
      end

      def headshot_image
        @headshot_image ||= PosterCanvas.load_attachment(@brand&.headshot, max_side: 512)
      end

      def photo_max_side
        ENV.fetch("POSTER_PHOTO_MAX_PX", "2400").to_i
      end

      def release_memory!
        @photo_image = @logo_image = @headshot_image = nil
      end

      def render_just_listed(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb(width, height, *ink_rgb, alpha: 36), x: 0, y: 0)
        fade_h = (height * 0.46).round
        canvas.composite(PosterCanvas.bottom_fade(width, fade_h, ink_rgb, alpha: 226), x: 0, y: height - fade_h)

        badge_bottom = draw_stage_badge(canvas, x: 56, y: 56, size: 22, pad_x: 44, pad_y: 28)

        y = height - 56
        y = paint_brand_row(canvas, x: 56, y_bottom: y, width: 968, logo_size: 56, size: 22)
        y = stack_up(canvas, @listing.ph_badges.join(" · "), width: 968, size: 20, x: 56, y: y, gap: 14) if @listing.ph_badges.any?
        y = stack_up(canvas, @listing.facts_line, width: 968, size: 24, x: 56, y: y, gap: 12) if @listing.facts_line.present?
        y = stack_up(canvas, @listing.peso_label, width: 968, size: 42, x: 56, y: y, gap: 12, font: "Sans Bold", rgb: accent_rgb)
        if @listing.stage == "price_reduced" && @listing.previous_price_amount.present?
          y = stack_up(canvas, @listing.previous_peso_label, width: 968, size: 24, x: 56, y: y, gap: 6)
        end

        location_h = block_height(@listing.location.to_s.upcase, width: 968, size: 20)
        title_budget = y - badge_bottom - 28 - location_h
        title_budget = [ title_budget, lines_height(72, 2) ].min
        y = stack_up(canvas, @listing.title, width: 968, size: 72, x: 56, y: y, gap: 14, font: "Serif Bold", max_height: title_budget)
        stack_up(canvas, @listing.location.to_s.upcase, width: 968, size: 20, x: 56, y: y, gap: 0, rgb: CREAM, max_height: 36)

        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_price_card(width, height)
        canvas = PosterCanvas.new(width, height, background: CREAM)
        layout = price_card_layout(width, height)

        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, layout[:photo_h]), x: 0, y: 0)
        else
          canvas.composite(PosterCanvas.solid_rgb(width, layout[:photo_h], *ink_rgb), x: 0, y: 0)
        end

        y = layout[:body_y]
        max_y = layout[:max_y]
        y = stack_down(canvas, @listing.stage_banner, width: 968, size: 16, x: 56, y: y, gap: 8, rgb: accent_rgb, font: "Sans Bold", max_y: max_y)
        y = stack_down(canvas, @listing.title, width: 968, size: 42, x: 56, y: y, gap: 8, font: "Serif Bold", rgb: ink_rgb, max_height: layout[:title_budget], max_y: max_y)
        y = stack_down(canvas, @listing.location, width: 968, size: 20, x: 56, y: y, gap: 16, rgb: ink_rgb, max_height: 32, max_y: max_y)
        if y + 4 <= max_y
          canvas.composite(PosterCanvas.solid_rgb(88, 4, *accent_rgb), x: 56, y: y)
          y += 18
        end
        y = stack_down(canvas, @listing.peso_label, width: 968, size: 40, x: 56, y: y, gap: 10, font: "Sans Bold", rgb: accent_rgb, max_y: max_y)
        y = stack_down(canvas, @listing.facts_line, width: 968, size: 20, x: 56, y: y, gap: 6, rgb: ink_rgb, max_height: 28, max_y: max_y) if @listing.facts_line.present?
        if layout[:include_badges]
          stack_down(canvas, @listing.ph_badges.first(2).join(" · "), width: 968, size: 16, x: 56, y: y, gap: 0, rgb: ink_rgb, max_height: 24, max_y: max_y)
        end

        footer_h = layout[:footer_h]
        canvas.composite(PosterCanvas.solid_rgb(width, footer_h, *ink_rgb), x: 0, y: height - footer_h)
        draw_price_card_footer(canvas, width, height, footer_h)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_agent_card(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        inset = 32
        inner_w = width - (inset * 2)
        inner_h = height - (inset * 2)
        avatar_size = 120
        band_pad = 32
        text_w = inner_w - 64 - avatar_size - 20

        name_h = block_height(@brand.name.to_s, width: text_w, size: 30, font: "Serif Bold")
        price_h = block_height(@listing.peso_label, width: text_w, size: 26, font: "Sans Bold")
        cta = "DM for viewing#{@brand&.phone.present? ? " · #{@brand.phone}" : ""}"
        cta_h = block_height(cta, width: text_w, size: 16)
        identity_h = name_h + 6 + price_h + 8 + cta_h
        band_h = [ avatar_size, identity_h ].max + (band_pad * 2)
        photo_h = inner_h - band_h
        copy_width = inner_w - 56

        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, inner_w, photo_h), x: inset, y: inset)
        end
        fade_h = [ 220, (photo_h * 0.36).round ].max
        canvas.composite(PosterCanvas.bottom_fade(inner_w, fade_h, ink_rgb, alpha: 230), x: inset, y: inset + photo_h - fade_h)
        draw_stage_badge(canvas, x: inset + 32, y: inset + 32, size: 18, pad_x: 44, pad_y: 28, label: "YOUR AGENT")

        title_budget = lines_height(42, 2)
        title_bottom = inset + photo_h - 32
        title_bottom = stack_up(canvas, @listing.title, width: copy_width, size: 42, x: inset + 28, y: title_bottom, gap: 10, font: "Serif Bold", max_height: title_budget)
        stack_up(canvas, @listing.location.to_s.upcase, width: copy_width, size: 16, x: inset + 28, y: title_bottom, gap: 0, rgb: CREAM, max_height: 28)

        band_y = inset + photo_h
        content_h = [ avatar_size, identity_h ].max
        content_y = band_y + ((band_h - content_h) / 2.0)
        avatar_x = inset + 28
        if headshot_image
          canvas.composite(PosterCanvas.rounded_image(headshot_image, avatar_size, radius: avatar_size / 2), x: avatar_x, y: content_y)
        else
          letter = @brand.name.to_s.gsub(/[^A-Za-z]/, "").first.presence || @brand.name.to_s.first.to_s
          initial = PosterCanvas.tinted_text(letter.to_s.upcase, width: avatar_size, size: 42, rgb: WHITE, font: "Serif Bold")
          badge = PosterCanvas.filled_circle(avatar_size, accent_rgb)
          canvas.composite(badge, x: avatar_x, y: content_y)
          canvas.composite(initial, x: avatar_x + ((avatar_size - initial.width) / 2.0), y: content_y + ((avatar_size - initial.height) / 2.0)) if initial
        end

        text_x = avatar_x + avatar_size + 20
        text_y = content_y + ((content_h - identity_h) / 2.0)
        text_y = stack_down(canvas, @brand.name.to_s, width: text_w, size: 30, x: text_x, y: text_y, gap: 6, font: "Serif Bold", max_height: lines_height(30, 2))
        text_y = stack_down(canvas, @listing.peso_label, width: text_w, size: 26, x: text_x, y: text_y, gap: 8, font: "Sans Bold", rgb: accent_rgb)
        stack_down(canvas, cta, width: text_w, size: 16, x: text_x, y: text_y, gap: 0, max_height: 28)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_story(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb(width, (height * 0.42).round, *ink_rgb, alpha: 230), x: 0, y: height - (height * 0.42).round)

        badge = PosterCanvas.tinted_text(@listing.stage_banner, width: 420, size: 24, rgb: WHITE, font: "Sans Bold")
        badge_bg = PosterCanvas.solid_rgb(badge.width + 48, badge.height + 32, *accent_rgb)
        canvas.composite(badge_bg, x: 56, y: 72)
        canvas.composite(badge, x: 80, y: 88)
        composite_logo(canvas, x: width - 120, y: 72, size: 64) if logo_image

        y = height - 96
        y = stack_up(canvas, "#{@brand.name}#{@brand&.phone.present? ? " · #{@brand.phone}" : ""}", width: 968, size: 26, x: 56, y: y, gap: 0)
        y = stack_up(canvas, @listing.facts_line, width: 968, size: 28, x: 56, y: y, gap: 12) if @listing.facts_line.present?
        y = stack_up(canvas, @listing.peso_label, width: 968, size: 48, x: 56, y: y, gap: 10, font: "Sans Bold")
        location_h = block_height(@listing.location, width: 968, size: 30)
        y = stack_up(canvas, @listing.title, width: 968, size: 72, x: 56, y: y, gap: 12, font: "Serif Bold", max_height: lines_height(72, 3))
        stack_up(canvas, @listing.location, width: 968, size: 30, x: 56, y: y, gap: 0, max_height: [ location_h, 48 ].max)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_landscape(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb((width * 0.55).round, height, *ink_rgb, alpha: 210), x: 0, y: 0)

        badge = PosterCanvas.tinted_text(@listing.stage_banner, width: 420, size: 22, rgb: WHITE, font: "Sans Bold")
        badge_bg = PosterCanvas.solid_rgb(badge.width + 44, badge.height + 28, *accent_rgb)
        canvas.composite(badge_bg, x: 72, y: 72)
        canvas.composite(badge, x: 94, y: 86)

        y = height - 72
        y = paint_brand_row(canvas, x: 72, y_bottom: y, width: 760, logo_size: 56, size: 24)
        y = stack_up(canvas, @listing.facts_line, width: 760, size: 26, x: 72, y: y, gap: 12) if @listing.facts_line.present?
        y = stack_up(canvas, @listing.peso_label, width: 760, size: 44, x: 72, y: y, gap: 10, font: "Sans Bold")
        location_h = block_height(@listing.location, width: 760, size: 28)
        y = stack_up(canvas, @listing.title, width: 760, size: 64, x: 72, y: y, gap: 12, font: "Serif Bold", max_height: lines_height(64, 2))
        stack_up(canvas, @listing.location, width: 760, size: 28, x: 72, y: y, gap: 0, max_height: [ location_h, 40 ].max)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_fb_banner(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb((width * 0.62).round, height, *ink_rgb, alpha: 215), x: 0, y: 0)

        badge = PosterCanvas.tinted_text(@listing.stage_banner, width: 320, size: 16, rgb: WHITE, font: "Sans Bold")
        badge_bg = PosterCanvas.solid_rgb(badge.width + 36, badge.height + 20, *accent_rgb)
        canvas.composite(badge_bg, x: 48, y: 40)
        canvas.composite(badge, x: 66, y: 50)

        facts = @listing.facts_line.present? ? " · #{@listing.facts_line}" : ""
        left_y = height - 36
        left_y = paint_brand_row(canvas, x: 48, y_bottom: left_y, width: 640, logo_size: 40, size: 16)
        left_y = stack_up(canvas, "#{@listing.peso_label}#{facts}", width: 640, size: 22, x: 48, y: left_y, gap: 8, font: "Sans Bold", max_height: 52)
        left_y = stack_up(canvas, @listing.title, width: 640, size: 36, x: 48, y: left_y, gap: 8, font: "Serif Bold", max_height: lines_height(36, 2))
        stack_up(canvas, @listing.location, width: 640, size: 16, x: 48, y: left_y, gap: 0, max_height: 24)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def draw_stage_badge(canvas, x:, y:, size: 20, pad_x: 44, pad_y: 28, label: nil)
        text = label || @listing.stage_banner
        badge = PosterCanvas.tinted_text(text.to_s.upcase, width: 420, size: size, rgb: WHITE, font: "Sans Bold")
        return y if badge.nil?

        bg = PosterCanvas.rounded_fill(badge.width + pad_x, badge.height + pad_y, accent_rgb, radius: 10)
        canvas.composite(bg, x: x, y: y)
        canvas.composite(badge, x: x + (pad_x / 2.0), y: y + (pad_y / 2.0))
        y + bg.height
      end

      def price_card_layout(_width, height)
        footer_h = 88
        pad_top = 36
        pad_bottom = 24
        text_w = 968
        title_budget = lines_height(42, 2)
        badges = @listing.ph_badges.first(2).join(" · ")

        stage_h = block_height(@listing.stage_banner, width: text_w, size: 16, font: "Sans Bold")
        title_h = copy_block(@listing.title, width: text_w, size: 42, font: "Serif Bold", rgb: ink_rgb, max_height: title_budget)&.height || 0
        location_h = block_height(@listing.location, width: text_w, size: 20)
        peso_h = block_height(@listing.peso_label, width: text_w, size: 40, font: "Sans Bold")
        facts_h = @listing.facts_line.present? ? block_height(@listing.facts_line, width: text_w, size: 20) : 0
        badges_h = badges.present? ? block_height(badges, width: text_w, size: 16) : 0

        required = stage_h + 8 + title_h + 8 + location_h + 16 + 4 + 14 + peso_h
        required += 10 + facts_h if facts_h.positive?
        with_badges = required + (badges_h.positive? ? 6 + badges_h : 0)
        include_badges = badges.present? && (with_badges + pad_top + pad_bottom) <= (height * 0.38).round
        body_h = include_badges ? with_badges : required
        photo_h = height - footer_h - pad_top - pad_bottom - body_h

        {
          photo_h: photo_h,
          footer_h: footer_h,
          body_y: photo_h + pad_top,
          max_y: height - footer_h - pad_bottom,
          title_budget: title_budget,
          include_badges: include_badges
        }
      end

      def draw_price_card_footer(canvas, width, height, footer_h)
        footer_y = height - footer_h
        text_x = 56
        logo_size = 48
        if logo_image
          composite_logo(canvas, x: 56, y: footer_y + ((footer_h - logo_size) / 2.0), size: logo_size)
          text_x = 56 + logo_size + 16
        end

        name_h = block_height(@brand.name.to_s, width: 480, size: 20, font: "Sans Bold")
        phone_h = @brand&.phone.present? ? block_height(@brand.phone.to_s, width: 480, size: 16) : 0
        block_h = name_h + (phone_h.positive? ? 4 + phone_h : 0)
        text_y = footer_y + ((footer_h - block_h) / 2.0)
        text_y = stack_down(canvas, @brand.name.to_s, width: width - text_x - 56, size: 20, x: text_x, y: text_y, gap: 4, font: "Sans Bold", max_height: 28)
        stack_down(canvas, @brand.phone.to_s, width: width - text_x - 56, size: 16, x: text_x, y: text_y, gap: 0) if @brand&.phone.present?
      end

      def stack_text(canvas, text, width:, size:, x:, y:, rgb: WHITE, font: "Sans", max_height: nil)
        block = copy_block(text, width: width, size: size, rgb: rgb, font: font, max_height: max_height)
        return y if block.nil?

        canvas.composite(block, x: x, y: y)
        y + block.height
      end

      def stack_down(canvas, text, width:, size:, x:, y:, gap: 12, rgb: WHITE, font: "Sans", max_height: nil, max_y: nil)
        block = copy_block(text, width: width, size: size, rgb: rgb, font: font, max_height: max_height)
        return y if block.nil?
        return y if max_y && y + block.height > max_y

        canvas.composite(block, x: x, y: y)
        y + block.height + gap
      end

      def stack_up(canvas, text, width:, size:, x:, y:, gap: 12, rgb: WHITE, font: "Sans", max_height: nil)
        available = max_height || [ y, 1 ].max
        block = copy_block(text, width: width, size: size, rgb: rgb, font: font, max_height: available)
        return y if block.nil?

        top = y - block.height
        canvas.composite(block, x: x, y: [ top, 0 ].max)
        [ top, 0 ].max - gap
      end

      def copy_block(text, width:, size:, rgb: WHITE, font: "Sans", max_height: nil)
        label = text.to_s.gsub(/\s+/, " ").strip
        return nil if label.blank?

        min_size = [ (size * 0.6).round, 16 ].max
        current = size
        block = nil

        while current >= min_size
          block = PosterCanvas.tinted_text(label, width: width, size: current, rgb: rgb, font: font)
          break if block.nil? || max_height.nil? || block.height <= max_height

          current -= 3
        end
        return block if block.nil? || max_height.nil? || block.height <= max_height

        words = label.split
        while words.size > 1
          words.pop
          trial = "#{words.join(" ")}…"
          block = PosterCanvas.tinted_text(trial, width: width, size: min_size, rgb: rgb, font: font)
          return block if block.height <= max_height
        end
        block
      end

      def block_height(text, width:, size:, font: "Sans", rgb: WHITE)
        copy_block(text, width: width, size: size, rgb: rgb, font: font)&.height || 0
      end

      def lines_height(size, lines)
        (size * TITLE_LINE_HEIGHT * lines).ceil
      end

      def paint_brand_row(canvas, x:, y_bottom:, width:, logo_size:, size:, rgb: WHITE)
        line = [ @brand&.name, @brand&.phone.presence ].compact.join(" · ")
        has_logo = logo_image.present?
        text_x = has_logo ? x + logo_size + 16 : x
        text_w = has_logo ? width - logo_size - 16 : width
        block = copy_block(line, width: text_w, size: size, rgb: rgb, max_height: lines_height(size, 2))
        row_h = [ has_logo ? logo_size : 0, block&.height || 0 ].max
        top = y_bottom - row_h - 16
        composite_logo(canvas, x: x, y: top + ((row_h - logo_size) / 2.0), size: logo_size) if has_logo
        canvas.composite(block, x: text_x, y: top + ((row_h - block.height) / 2.0)) if block
        top
      end

      def composite_logo(canvas, x:, y:, size:)
        logo = PosterCanvas.rounded_image(logo_image, size, radius: 12)
        canvas.composite(logo, x: x, y: y)
      end

      def apply_watermark(canvas, width, height)
        return unless @watermark

        mark = PosterCanvas.watermark(width, height)
        return unless mark

        inset = PosterCanvas.watermark_corner_inset(width, height)
        x = [ width - mark.width - inset, inset ].max
        y = [ height - mark.height - inset, inset ].max
        canvas.composite(mark, x: x, y: y)
      end
  end
end
