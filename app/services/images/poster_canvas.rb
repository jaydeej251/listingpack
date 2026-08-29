require "vips"

module Images
  class PosterCanvas
    attr_reader :image

    def initialize(width, height, background: [ 20, 33, 61 ])
      @width = width
      @height = height
      @image = self.class.solid_rgb(width, height, *background)
    end

    def composite(overlay, x:, y:)
      @image = @image.composite2(overlay, :over, x: x, y: y)
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

    def self.load_attachment(attachment)
      return nil if attachment.blank?

      blob = attachment
      blob = attachment.blob if attachment.respond_to?(:blob)
      return nil unless blob&.respond_to?(:download)

      Vips::Image.new_from_buffer(blob.download, "")
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

    def self.text_block(text, width:, size:, color: [ 255, 255, 255 ], font: "Sans", dpi: 144)
      label = text.to_s.strip
      return solid_rgb(1, 1, *color, alpha: 0) if label.blank?

      Vips::Image.text(
        label,
        width: width,
        font: "#{font} #{size}",
        dpi: dpi,
        align: :low,
        rgba: true
      ).copy(interpretation: :srgb)
    rescue Vips::Error
      solid_rgb(1, 1, *color, alpha: 0)
    end

    def self.tinted_text(text, width:, size:, rgb:, font: "Sans")
      block = text_block(text, width: width, size: size, color: rgb, font: font)
      return block if block.bands < 4

      alpha = block[3]
      rgb_layer = solid_rgb(block.width, block.height, *rgb)
      rgb_layer.bandjoin(alpha)
    end

    def self.rounded_image(source, size, radius: 12)
      mask = Vips::Image.black(size, size) + 255
      mask = mask.draw_rect([ 255 ], 0, 0, size, size, fill: true, radius: radius)
      resized = cover_crop(source, size, size)
      resized.bandjoin(mask)
    end

    def self.watermark(width, height, label: "LISTINGPACK FREE")
      text = text_block(label, width: width, size: 40, color: [ 255, 255, 255 ], font: "Sans Bold")
      return nil if text.width <= 1

      text.rotate(18, background: [ 0, 0, 0, 0 ])
    rescue Vips::Error
      nil
    end
  end
end
