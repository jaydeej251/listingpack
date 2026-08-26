# aws-sdk-s3 1.178+ sends CRC32 in addition to Active Storage's Content-MD5.
# Cloudflare R2 rejects that. Apply on every S3 client (upload, HEAD, GET), not only
# the options parsed from storage.yml.
if ENV["AWS_BUCKET"].present?
  require "aws-sdk-s3"
  Aws.config.update(
    request_checksum_calculation: "when_required",
    response_checksum_validation: "when_required"
  )
end
