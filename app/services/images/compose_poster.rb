require "stringio"

module Images
  class ComposePoster
    class Error < StandardError; end

    WHITE = [ 255, 255, 255 ].freeze
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

        overlay_h = (height * 0.55).round
        canvas.composite(PosterCanvas.solid_rgb(width, overlay_h, *ink_rgb, alpha: 220), x: 0, y: height - overlay_h)
        apply_watermark(canvas, width, height)

        badge = PosterCanvas.tinted_text(@listing.stage_banner, width: 420, size: 22, rgb: WHITE, font: "Sans Bold")
        badge_bg = PosterCanvas.solid_rgb(badge.width + 44, badge.height + 28, *accent_rgb)
        canvas.composite(badge_bg, x: 56, y: 56)
        canvas.composite(badge, x: 78, y: 70)
        badge_bottom = 56 + badge_bg.height

        y = height - 56
        y = paint_brand_row(canvas, x: 56, y_bottom: y, width: 968, logo_size: 56, size: 22)
        y = stack_up(canvas, @listing.ph_badges.join(" · "), width: 968, size: 20, x: 56, y: y, gap: 14) if @listing.ph_badges.any?
        y = stack_up(canvas, @listing.facts_line, width: 968, size: 24, x: 56, y: y, gap: 12) if @listing.facts_line.present?
        y = stack_up(canvas, @listing.peso_label, width: 968, size: 42, x: 56, y: y, gap: 10, font: "Sans Bold")
        if @listing.stage == "price_reduced" && @listing.previous_price_amount.present?
          y = stack_up(canvas, @listing.previous_peso_label, width: 968, size: 24, x: 56, y: y, gap: 6)
        end

        location_h = block_height(@listing.location, width: 968, size: 28)
        title_budget = y - badge_bottom - 28 - location_h
        title_budget = [ title_budget, lines_height(72, 2) ].min
        y = stack_up(canvas, @listing.title, width: 968, size: 72, x: 56, y: y, gap: 18, font: "Serif Bold", max_height: title_budget)
        stack_up(canvas, @listing.location, width: 968, size: 28, x: 56, y: y, gap: 0, max_height: 40)

        canvas.to_png_bytes
      end

      def render_price_card(width, height)
        canvas = PosterCanvas.new(width, height, background: [ 243, 238, 228 ])
        photo_h = 620
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, photo_h), x: 0, y: 0)
        else
          canvas.composite(PosterCanvas.solid_rgb(width, photo_h, *ink_rgb), x: 0, y: 0)
        end
        apply_watermark(canvas, width, height)

        facts = @listing.facts_line.presence || "Ask for the full spec sheet"
        badges = @listing.ph_badges.join(" · ")
        peso_h = block_height(@listing.peso_label, width: 520, size: 40, font: "Sans Bold")
        facts_h = block_height(facts, width: 520, size: 20)
        badges_h = badges.present? ? block_height(badges, width: 520, size: 16) : 0
        footer_h = peso_h + 8 + facts_h + (badges_h > 0 ? 8 + badges_h : 0)

        brand_h = block_height(@brand.name.to_s, width: 300, size: 20, font: "Sans Bold")
        phone_h = @brand&.phone.present? ? block_height(@brand.phone.to_s, width: 300, size: 18) : 0
        logo_h = logo_image ? 58 : 0
        brand_col_h = logo_h + brand_h + (phone_h > 0 ? 6 + phone_h : 0)

        footer_top = height - 40 - [ footer_h, brand_col_h ].max
        header_y = photo_h + 40
        location_h = block_height(@listing.location, width: 968, size: 22)
        title_budget = footer_top - header_y - 28 - location_h
        title_budget = [ title_budget, lines_height(48, 2) ].min
        title_budget = [ title_budget, 36 ].max

        y = header_y
        y = stack_down(canvas, @listing.stage_banner, width: 968, size: 18, x: 56, y: y, gap: 8, rgb: accent_rgb, font: "Sans Bold")
        y = stack_down(canvas, @listing.title, width: 968, size: 48, x: 56, y: y, gap: 12, font: "Serif Bold", rgb: ink_rgb, max_height: title_budget)
        stack_down(canvas, @listing.location, width: 968, size: 22, x: 56, y: y, gap: 0, rgb: ink_rgb, max_height: 40)

        y = height - 40
        y = stack_up(canvas, badges, width: 600, size: 15, x: 56, y: y, gap: 8, rgb: ink_rgb, max_height: 38) if badges.present?
        y = stack_up(canvas, facts, width: 560, size: 20, x: 56, y: y, gap: 8, rgb: ink_rgb, max_height: 28)
        stack_up(canvas, @listing.peso_label, width: 520, size: 40, x: 56, y: y, gap: 0, font: "Sans Bold", rgb: ink_rgb)

        right_x = width - 356
        brand_y = height - 40 - brand_col_h
        if logo_image
          composite_logo(canvas, x: width - 104, y: brand_y, size: 48)
          brand_y += 58
        end
        brand_y = stack_down(canvas, @brand.name.to_s, width: 300, size: 20, x: right_x, y: brand_y, gap: 6, rgb: ink_rgb, font: "Sans Bold")
        stack_down(canvas, @brand.phone.to_s, width: 300, size: 18, x: right_x, y: brand_y, gap: 0, rgb: ink_rgb) if @brand&.phone.present?

        canvas.to_png_bytes
      end

      def render_agent_card(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        inset = 36
        inner_w = width - (inset * 2)
        inner_h = height - (inset * 2)
        photo_h = (inner_h * 0.64).round
        copy_width = inner_w - 72

        title_budget = lines_height(48, 2)
        title_block = copy_block(@listing.title, width: copy_width, size: 48, font: "Serif Bold", max_height: title_budget)
        label_block = copy_block("YOUR AGENT", width: copy_width, size: 20, rgb: accent_rgb, font: "Sans Bold")
        title_gap = 10
        copy_h = (label_block&.height || 0) + (title_block ? title_gap + title_block.height : 0)
        copy_top = inset + photo_h - 24 - copy_h
        overlay_h = copy_h + 56

        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, inner_w, photo_h), x: inset, y: inset)
        end
        canvas.composite(PosterCanvas.solid_rgb(inner_w, overlay_h, *ink_rgb, alpha: 200), x: inset, y: inset + photo_h - overlay_h)
        apply_watermark(canvas, width, height)

        y = copy_top
        if label_block
          canvas.composite(label_block, x: inset + 36, y: y)
          y += label_block.height + title_gap
        end
        canvas.composite(title_block, x: inset + 36, y: y) if title_block

        footer_y = inset + photo_h + 36
        if headshot_image
          canvas.composite(PosterCanvas.rounded_image(headshot_image, 148, radius: 74), x: inset + 40, y: footer_y)
        else
          initial = PosterCanvas.tinted_text(@brand.name.to_s.first.to_s, width: 80, size: 42, rgb: WHITE, font: "Serif Bold")
          badge = PosterCanvas.filled_circle(148, accent_rgb)
          canvas.composite(badge, x: inset + 40, y: footer_y)
          canvas.composite(initial, x: inset + 40 + ((148 - initial.width) / 2.0), y: footer_y + ((148 - initial.height) / 2.0))
        end

        text_x = inset + 210
        y = footer_y + 8
        y = stack_down(canvas, @brand.name.to_s, width: inner_w - 250, size: 34, x: text_x, y: y, gap: 8, font: "Serif Bold", max_height: lines_height(34, 2))
        y = stack_down(canvas, "#{@listing.location} · #{@listing.peso_label}", width: inner_w - 250, size: 22, x: text_x, y: y, gap: 8, max_height: 48)
        stack_down(canvas, "DM for viewing#{@brand&.phone.present? ? " · #{@brand.phone}" : ""}", width: inner_w - 250, size: 22, x: text_x, y: y, gap: 0, max_height: 48)
        canvas.to_png_bytes
      end

      def render_story(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb(width, (height * 0.42).round, *ink_rgb, alpha: 230), x: 0, y: height - (height * 0.42).round)
        apply_watermark(canvas, width, height)

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
        canvas.to_png_bytes
      end

      def render_landscape(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb((width * 0.55).round, height, *ink_rgb, alpha: 210), x: 0, y: 0)
        apply_watermark(canvas, width, height)

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
        canvas.to_png_bytes
      end

      def render_fb_banner(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb((width * 0.62).round, height, *ink_rgb, alpha: 215), x: 0, y: 0)
        apply_watermark(canvas, width, height)

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
        canvas.to_png_bytes
      end

      def stack_text(canvas, text, width:, size:, x:, y:, rgb: WHITE, font: "Sans", max_height: nil)
        block = copy_block(text, width: width, size: size, rgb: rgb, font: font, max_height: max_height)
        return y if block.nil?

        canvas.composite(block, x: x, y: y)
        y + block.height
      end

      def stack_down(canvas, text, width:, size:, x:, y:, gap: 12, rgb: WHITE, font: "Sans", max_height: nil)
        block = copy_block(text, width: width, size: size, rgb: rgb, font: font, max_height: max_height)
        return y if block.nil?

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

        x = ((width - mark.width) / 2.0).round
        y = ((height * 0.32) - (mark.height / 2.0)).round
        y = [ [ y, 16 ].max, height - mark.height - 16 ].min
        canvas.composite(mark, x: x, y: y)
      end
  end
end
