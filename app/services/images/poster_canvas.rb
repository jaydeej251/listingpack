require "vips"

module Images
  class PosterCanvas
    attr_reader :image

    # Pango font sizes are points. 72 DPI makes 1pt == 1px, matching the HTML
    # template pixel sizes. 144 DPI doubled every glyph, which overflowed the
    # 1080px cards and stacked titles over price/facts.
    TEXT_DPI = 72
    WATERMARK_OPACITY = 0.08
    WATERMARK_SIZE = 46

    def initialize(width, height, background: [ 20, 33, 61 ])
      @width = width
      @height = height
      @image = self.class.solid_rgb(width, height, *background)
    end

    def composite(overlay, x:, y:)
      @image = @image.composite2(overlay, :over, x: x.round, y: y.round)
      self
    end

    def to_png_bytes
      @image.write_to_buffer(".png")
    end

    def self.solid_rgb(width, height, red, green, blue, alpha: 255)
      rgb = Vips::Image.black(width, height).new_from_image([ red, green, blue ]).copy(interpretation: :srgb)
      alpha >= 255 ? rgb : rgb.bandjoin(alpha)
    end

    def self.cover_crop(source, target_width, target_height)
      scale = [ target_width.to_f / source.width, target_height.to_f / source.height ].max
      scaled = source.resize(scale)
      left = [ ((scaled.width - target_width) / 2.0).round, 0 ].max
      top = [ ((scaled.height - target_height) / 2.0).round, 0 ].max
      scaled.crop(left, top, target_width, target_height)
    end

    def self.load_attachment(attachment, max_side: 2400)
      return nil if attachment.blank?

      blob = attachment
      blob = attachment.blob if attachment.respond_to?(:blob)
      return nil unless blob&.respond_to?(:download)

      # Shrink during decode — avoids loading multi-megapixel originals into RAM on small dynos.
      Vips::Image.thumbnail_buffer(blob.download, max_side, size: :down)
    rescue Vips::Error, ActiveStorage::FileNotFoundError
      nil
    end

    def self.parse_hex(hex, fallback: [ 20, 33, 61 ])
      value = hex.to_s.delete("#")
      return fallback if value.blank?

      value = value.chars.map { |char| char * 2 }.join if value.length == 3
      return fallback unless value.match?(/\A[0-9a-fA-F]{6}\z/)

      [ value[0, 2].hex, value[2, 2].hex, value[4, 2].hex ]
    end

    def self.text_block(text, width:, size:, color: [ 255, 255, 255 ], font: "Sans", dpi: TEXT_DPI)
      label = text.to_s.strip
      return solid_rgb(1, 1, *color, alpha: 0) if label.blank?

      Vips::Image.text(
        label,
        width: width,
        font: "#{font} #{size}",
        dpi: dpi,
        align: :low,
        wrap: :word,
        rgba: true
      ).copy(interpretation: :srgb)
    rescue Vips::Error
      solid_rgb(1, 1, *color, alpha: 0)
    end

    def self.tinted_text(text, width:, size:, rgb:, font: "Sans", dpi: TEXT_DPI)
      block = text_block(text, width: width, size: size, color: rgb, font: font, dpi: dpi)
      return block if block.bands < 4

      alpha = block[3]
      rgb_layer = solid_rgb(block.width, block.height, *rgb)
      trim_alpha(rgb_layer.bandjoin(alpha))
    end

    def self.trim_alpha(image)
      return image if image.bands < 4

      alpha = image[3]
      left, top, width, height = alpha.find_trim(threshold: 1)
      return image if width <= 0 || height <= 0

      image.crop(left, top, width, height)
    rescue Vips::Error
      image
    end

    def self.with_opacity(image, opacity)
      opacity = opacity.to_f.clamp(0.0, 1.0)
      return image if image.nil? || opacity >= 1.0

      if image.bands >= 4
        rgb = image.extract_band(0, n: 3)
        alpha = (image[3] * opacity).cast(:uchar)
        rgb.bandjoin(alpha)
      else
        image.bandjoin((255 * opacity).round)
      end
    end

    def self.rounded_image(source, size, radius: 12)
      resized = cover_crop(source, size, size)
      resized = resized.extract_band(0, n: 3) if resized.bands > 3
      return resized if radius.to_i <= 0

      mask = Vips::Image.black(size, size)
      begin
        if radius >= (size / 2.0)
          mask = mask.draw_circle([ 255 ], size / 2, size / 2, (size / 2) - 1, fill: true)
        else
          mask = mask.draw_rect([ 255 ], 0, 0, size, size, fill: true, radius: radius)
        end
      rescue Vips::Error
        return resized
      end

      resized.bandjoin(mask)
    end

    def self.filled_circle(size, rgb)
      rgb_layer = solid_rgb(size, size, *rgb)
      mask = Vips::Image.black(size, size)
      mask = mask.draw_circle([ 255 ], size / 2, size / 2, (size / 2) - 1, fill: true)
      rgb_layer.bandjoin(mask)
    rescue Vips::Error
      solid_rgb(size, size, *rgb)
    end

    def self.watermark(width, height, label: "LISTINGPACK FREE")
      size = [ WATERMARK_SIZE, ([ width, height ].min / 20.0).round ].max
      text = tinted_text(label, width: (width * 0.88).round, size: size, rgb: [ 255, 255, 255 ], font: "Sans Bold")
      return nil if text.nil? || text.width <= 1

      faded = with_opacity(text, WATERMARK_OPACITY)
      faded.rotate(-18, background: [ 0, 0, 0, 0 ])
    rescue Vips::Error
      nil
    end
  end
end
