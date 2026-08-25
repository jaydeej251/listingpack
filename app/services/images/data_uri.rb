require "base64"

module Images
  class DataUri
    def self.from_attachment(attachment)
      return nil if attachment.blank?

      # HasManyAttached / HasOneAttached proxies — unwrap to a record first.
      if attachment.is_a?(ActiveStorage::Attached::Many)
        attachment = attachment.first
        return nil if attachment.blank?
      elsif attachment.is_a?(ActiveStorage::Attached::One)
        return nil unless attachment.attached?
        attachment = attachment.attachment
        return nil if attachment.blank?
      end

      blob = attachment.try(:blob) || attachment
      return nil unless blob.respond_to?(:download)

      "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}"
    end
  end
end
