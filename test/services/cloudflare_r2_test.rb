require "test_helper"
require "digest"
require "aws-sdk-s3"

class CloudflareR2Test < ActiveSupport::TestCase
  FakeBlob = Struct.new(:service, :key) do
    def content_type = "image/png"

    def download
      service.download(key)
    end
  end

  AWS_ENV_KEYS = %w[
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    AWS_BUCKET
    AWS_REGION
    AWS_ENDPOINT
    AWS_FORCE_PATH_STYLE
  ].freeze

  setup do
    skip "R2 credentials are not in .env" unless r2_configured?
  end

  test "Active Storage S3 service can upload, download, and delete on R2" do
    key = probe_key("png")
    checksum = Digest::MD5.base64digest(probe_bytes)

    cloud_service.upload(key, StringIO.new(probe_bytes), checksum: checksum, content_type: "image/png")
    assert_equal probe_bytes, cloud_service.download(key)
    assert cloud_service.exist?(key)

    fake = fake_blob(key)
    uri = Images::DataUri.from_attachment(fake)
    assert_not_nil uri
    assert uri.start_with?("data:image/png;base64,")
  ensure
    cloud_service.delete(key) if key && r2_configured?
  end

  test "DataUri returns nil when the R2 object is gone" do
    key = probe_key("png")
    checksum = Digest::MD5.base64digest(probe_bytes)
    cloud_service.upload(key, StringIO.new(probe_bytes), checksum: checksum, content_type: "image/png")
    cloud_service.delete(key)

    assert_nil Images::DataUri.from_attachment(fake_blob(key))
  end

  test "R2 rejects MD5 plus CRC32 and accepts when_required" do
    key = probe_key("bin")
    body = "checksum-probe-#{SecureRandom.hex(8)}"
    md5 = Digest::MD5.base64digest(body)

    error = assert_raises(Aws::S3::Errors::InvalidRequest) do
      s3_client(checksums: "when_supported").put_object(
        bucket: aws_env.fetch("AWS_BUCKET"),
        key: key,
        body: body,
        content_md5: md5
      )
    end
    assert_match(/one non-default checksum/i, error.message)

    s3_client(checksums: "when_required").put_object(
      bucket: aws_env.fetch("AWS_BUCKET"),
      key: key,
      body: body,
      content_md5: md5
    )

    assert_equal body, s3_client(checksums: "when_required").get_object(
      bucket: aws_env.fetch("AWS_BUCKET"),
      key: key
    ).body.read
  ensure
    if r2_configured? && key
      s3_client(checksums: "when_required").delete_object(
        bucket: aws_env.fetch("AWS_BUCKET"),
        key: key
      )
    end
  end

  private
    def aws_env
      @aws_env ||= read_aws_env
    end

    def r2_configured?
      %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_BUCKET AWS_ENDPOINT].all? { |key| aws_env[key].present? }
    end

    def probe_bytes
      File.binread(Rails.root.join("public/icon.png"))
    end

    def probe_key(ext)
      "listingpack-probe/#{SecureRandom.uuid}.#{ext}"
    end

    def fake_blob(key)
      FakeBlob.new(cloud_service, key)
    end

    def cloud_service
      @cloud_service ||= ActiveStorage::Service.configure(:cloud, {
        "cloud" => {
          "service" => "S3",
          "access_key_id" => aws_env.fetch("AWS_ACCESS_KEY_ID"),
          "secret_access_key" => aws_env.fetch("AWS_SECRET_ACCESS_KEY"),
          "region" => aws_env["AWS_REGION"].presence || "auto",
          "bucket" => aws_env.fetch("AWS_BUCKET"),
          "endpoint" => aws_env.fetch("AWS_ENDPOINT"),
          "force_path_style" => aws_env.fetch("AWS_FORCE_PATH_STYLE", "true") != "false",
          "request_checksum_calculation" => "when_required",
          "response_checksum_validation" => "when_required"
        }
      })
    end

    def s3_client(checksums:)
      Aws::S3::Client.new(
        access_key_id: aws_env.fetch("AWS_ACCESS_KEY_ID"),
        secret_access_key: aws_env.fetch("AWS_SECRET_ACCESS_KEY"),
        region: aws_env["AWS_REGION"].presence || "auto",
        endpoint: aws_env.fetch("AWS_ENDPOINT"),
        force_path_style: aws_env.fetch("AWS_FORCE_PATH_STYLE", "true") != "false",
        request_checksum_calculation: checksums,
        response_checksum_validation: checksums
      )
    end

    def read_aws_env
      values = {}
      AWS_ENV_KEYS.each { |key| values[key] = ENV[key] if ENV[key].to_s.present? }

      env_file = Rails.root.join(".env")
      return values unless env_file.file?

      env_file.each_line do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")

        line = line.sub(/\Aexport\s+/, "")
        key, eq, value = line.partition("=")
        next unless eq == "=" && AWS_ENV_KEYS.include?(key)
        next if values[key].present?

        value = value.strip
        if value.length >= 2 && ((value.start_with?('"') && value.end_with?('"')) || (value.start_with?("'") && value.end_with?("'")))
          value = value[1..-2]
        end
        values[key] = value
      end
      values
    end
end
