require "base64"

module Images
  class DataUri
    DOWNLOAD_ATTEMPTS = 3
    DOWNLOAD_BACKOFF = Rails.env.test? ? 0 : 0.4

    def self.from_attachment(attachment)
      blob = unwrap(attachment)
      return nil unless blob&.respond_to?(:download)

      bytes = read_bytes(blob)
      return nil if bytes.blank?

      "data:#{blob.content_type};base64,#{Base64.strict_encode64(bytes)}"
    end

    def self.read_bytes(blob)
      attempts = 0
      begin
        blob.service.download(blob.key)
      rescue ActiveStorage::FileNotFoundError
        attempts += 1
        if attempts < DOWNLOAD_ATTEMPTS
          sleep(DOWNLOAD_BACKOFF * attempts)
          retry
        end
        nil
      end
    end

    def self.unwrap(attachment)
      return nil if attachment.blank?

      if attachment.is_a?(ActiveStorage::Attached::Many)
        attachment = attachment.first
        return nil if attachment.blank?
      elsif attachment.is_a?(ActiveStorage::Attached::One)
        return nil unless attachment.attached?
        attachment = attachment.attachment
        return nil if attachment.blank?
      end

      attachment.try(:blob) || attachment
    end
    private_class_method :unwrap
  end
end
