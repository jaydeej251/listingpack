require "stringio"

module Images
  class ComposePoster
    class Error < StandardError; end

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
        @photo_image ||= PosterCanvas.load_attachment(@listing.photos.first)
      end

      def logo_image
        @logo_image ||= PosterCanvas.load_attachment(@brand&.logo)
      end

      def headshot_image
        @headshot_image ||= PosterCanvas.load_attachment(@brand&.headshot)
      end

      def render_just_listed(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end

        overlay_h = (height * 0.55).round
        canvas.composite(PosterCanvas.solid_rgb(width, overlay_h, *ink_rgb, alpha: 220), x: 0, y: height - overlay_h)

        badge = PosterCanvas.tinted_text(@listing.stage_banner, width: 420, size: 22, rgb: [ 255, 255, 255 ], font: "Sans Bold")
        badge_bg = PosterCanvas.solid_rgb(badge.width + 44, badge.height + 28, *accent_rgb)
        canvas.composite(badge_bg, x: 56, y: 56)
        canvas.composite(badge, x: 78, y: 70)

        y = height - 56
        y = stack_text(canvas, @brand&.phone.present? ? "#{@brand.name} · #{@brand.phone}" : @brand.name.to_s, width: 900, size: 22, x: 56, y: y, anchor: :bottom)
        y = stack_text(canvas, @listing.ph_badges.join(" · "), width: 900, size: 20, x: 56, y: y - 28, anchor: :bottom) if @listing.ph_badges.any?
        y = stack_text(canvas, @listing.facts_line, width: 900, size: 24, x: 56, y: y - 28, anchor: :bottom) if @listing.facts_line.present?
        y = stack_text(canvas, @listing.peso_label, width: 900, size: 42, x: 56, y: y - 28, anchor: :bottom, font: "Sans Bold")
        if @listing.stage == "price_reduced" && @listing.previous_price_amount.present?
          y = stack_text(canvas, @listing.previous_peso_label, width: 900, size: 24, x: 56, y: y - 20, anchor: :bottom)
        end
        y = stack_text(canvas, @listing.title, width: 900, size: 64, x: 56, y: y - 24, anchor: :bottom, font: "Serif Bold")
        stack_text(canvas, @listing.location, width: 900, size: 28, x: 56, y: y - 20, anchor: :bottom)

        composite_logo(canvas, x: 56, y: 56, size: 56) if logo_image
        apply_watermark(canvas, width, height)
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

        y = photo_h + 48
        y = stack_text(canvas, @listing.stage_banner, width: 900, size: 18, x: 56, y: y, rgb: accent_rgb, font: "Sans Bold")
        y = stack_text(canvas, @listing.title, width: 900, size: 48, x: 56, y: y + 16, font: "Serif Bold")
        y = stack_text(canvas, @listing.location, width: 900, size: 22, x: 56, y: y + 12, rgb: ink_rgb)
        y = stack_text(canvas, @listing.peso_label, width: 520, size: 40, x: 56, y: height - 180, font: "Sans Bold", rgb: ink_rgb)
        stack_text(canvas, (@listing.facts_line.presence || "Ask for the full spec sheet"), width: 520, size: 20, x: 56, y: y + 16, rgb: ink_rgb)
        stack_text(canvas, @brand.name.to_s, width: 300, size: 20, x: width - 360, y: height - 120, rgb: ink_rgb, font: "Sans Bold")
        stack_text(canvas, @brand.phone.to_s, width: 300, size: 18, x: width - 360, y: height - 88, rgb: ink_rgb) if @brand&.phone.present?
        composite_logo(canvas, x: width - 120, y: height - 180, size: 48) if logo_image
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_agent_card(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        inset = 36
        inner_w = width - (inset * 2)
        inner_h = height - (inset * 2)
        photo_h = (inner_h * 0.58).round

        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, inner_w, photo_h), x: inset, y: inset)
        end
        canvas.composite(PosterCanvas.solid_rgb(inner_w, photo_h, *ink_rgb, alpha: 180), x: inset, y: inset + photo_h - 120)

        stack_text(canvas, "YOUR AGENT", width: inner_w - 72, size: 20, x: inset + 36, y: inset + photo_h - 100, rgb: accent_rgb, font: "Sans Bold")
        stack_text(canvas, @listing.title, width: inner_w - 72, size: 48, x: inset + 36, y: inset + photo_h - 56, font: "Serif Bold")

        footer_y = inset + photo_h + 36
        if headshot_image
          canvas.composite(PosterCanvas.rounded_image(headshot_image, 148, radius: 74), x: inset + 40, y: footer_y)
        else
          initial = PosterCanvas.tinted_text(@brand.name.to_s.first.to_s, width: 80, size: 42, rgb: [ 255, 255, 255 ], font: "Serif Bold")
          badge = PosterCanvas.solid_rgb(148, 148, *accent_rgb)
          canvas.composite(badge, x: inset + 40, y: footer_y)
          canvas.composite(initial, x: inset + 74, y: footer_y + 52)
        end

        text_x = inset + 210
        stack_text(canvas, @brand.name.to_s, width: inner_w - 250, size: 34, x: text_x, y: footer_y + 8, font: "Serif Bold")
        stack_text(canvas, "#{@listing.location} · #{@listing.peso_label}", width: inner_w - 250, size: 22, x: text_x, y: footer_y + 56)
        stack_text(canvas, "DM for viewing#{@brand&.phone.present? ? " · #{@brand.phone}" : ""}", width: inner_w - 250, size: 22, x: text_x, y: footer_y + 96)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_story(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb(width, (height * 0.45).round, *ink_rgb, alpha: 230), x: 0, y: height - (height * 0.45).round)

        badge = PosterCanvas.tinted_text(@listing.stage_banner, width: 420, size: 24, rgb: [ 255, 255, 255 ], font: "Sans Bold")
        badge_bg = PosterCanvas.solid_rgb(badge.width + 48, badge.height + 32, *accent_rgb)
        canvas.composite(badge_bg, x: 56, y: 72)
        canvas.composite(badge, x: 80, y: 88)
        composite_logo(canvas, x: width - 120, y: 72, size: 64) if logo_image

        y = height - 96
        y = stack_text(canvas, "#{@brand.name}#{@brand&.phone.present? ? " · #{@brand.phone}" : ""}", width: 960, size: 26, x: 56, y: y, anchor: :bottom)
        y = stack_text(canvas, @listing.facts_line, width: 960, size: 28, x: 56, y: y - 36, anchor: :bottom) if @listing.facts_line.present?
        y = stack_text(canvas, @listing.peso_label, width: 960, size: 48, x: 56, y: y - 28, anchor: :bottom, font: "Sans Bold")
        y = stack_text(canvas, @listing.title, width: 960, size: 72, x: 56, y: y - 28, anchor: :bottom, font: "Serif Bold")
        stack_text(canvas, @listing.location, width: 960, size: 30, x: 56, y: y - 24, anchor: :bottom)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_landscape(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb((width * 0.55).round, height, *ink_rgb, alpha: 210), x: 0, y: 0)

        badge = PosterCanvas.tinted_text(@listing.stage_banner, width: 420, size: 22, rgb: [ 255, 255, 255 ], font: "Sans Bold")
        badge_bg = PosterCanvas.solid_rgb(badge.width + 44, badge.height + 28, *accent_rgb)
        canvas.composite(badge_bg, x: 72, y: 72)
        canvas.composite(badge, x: 94, y: 86)

        y = height - 72
        y = stack_text(canvas, "#{@brand.name}#{@brand&.phone.present? ? " · #{@brand.phone}" : ""}", width: 760, size: 24, x: 72, y: y, anchor: :bottom)
        composite_logo(canvas, x: 72, y: y - 72, size: 56) if logo_image
        y = stack_text(canvas, @listing.facts_line, width: 760, size: 26, x: 72, y: y - 28, anchor: :bottom) if @listing.facts_line.present?
        y = stack_text(canvas, @listing.peso_label, width: 760, size: 44, x: 72, y: y - 28, anchor: :bottom, font: "Sans Bold")
        y = stack_text(canvas, @listing.title, width: 760, size: 64, x: 72, y: y - 24, anchor: :bottom, font: "Serif Bold")
        stack_text(canvas, @listing.location, width: 760, size: 28, x: 72, y: y - 20, anchor: :bottom)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def render_fb_banner(width, height)
        canvas = PosterCanvas.new(width, height, background: ink_rgb)
        if photo_image
          canvas.composite(PosterCanvas.cover_crop(photo_image, width, height), x: 0, y: 0)
        end
        canvas.composite(PosterCanvas.solid_rgb((width * 0.62).round, height, *ink_rgb, alpha: 215), x: 0, y: 0)

        badge = PosterCanvas.tinted_text(@listing.stage_banner, width: 320, size: 16, rgb: [ 255, 255, 255 ], font: "Sans Bold")
        badge_bg = PosterCanvas.solid_rgb(badge.width + 36, badge.height + 20, *accent_rgb)
        canvas.composite(badge_bg, x: 48, y: 40)
        canvas.composite(badge, x: 66, y: 50)

        y = height - 40
        stack_text(canvas, @brand.phone.to_s, width: 260, size: 16, x: width - 308, y: y, anchor: :bottom) if @brand&.phone.present?
        stack_text(canvas, @brand.name.to_s, width: 260, size: 18, x: width - 308, y: y - 28, anchor: :bottom, font: "Sans Bold")
        composite_logo(canvas, x: width - 120, y: height - 120, size: 48) if logo_image

        facts = @listing.facts_line.present? ? " · #{@listing.facts_line}" : ""
        stack_text(canvas, "#{@listing.peso_label}#{facts}", width: 760, size: 24, x: 48, y: height - 40, anchor: :bottom, font: "Sans Bold")
        y = stack_text(canvas, @listing.title, width: 760, size: 40, x: 48, y: height - 76, anchor: :bottom, font: "Serif Bold")
        stack_text(canvas, @listing.location, width: 760, size: 18, x: 48, y: y - 16, anchor: :bottom)
        apply_watermark(canvas, width, height)
        canvas.to_png_bytes
      end

      def stack_text(canvas, text, width:, size:, x:, y:, rgb: [ 255, 255, 255 ], font: "Sans", anchor: :top)
        label = text.to_s.truncate(width / (size * 0.55))
        block = PosterCanvas.tinted_text(label, width: width, size: size, rgb: rgb, font: font)
        top = anchor == :bottom ? y - block.height : y
        canvas.composite(block, x: x, y: top)
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

        canvas.composite(mark, x: ((width - mark.width) / 2.0).round, y: ((height - mark.height) / 2.0).round)
      end
  end
end
