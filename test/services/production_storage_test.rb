require "test_helper"
require Rails.root.join("config/storage_resolver")

class ProductionStorageTest < ActiveSupport::TestCase
  test "resolver picks cloud when AWS_BUCKET is set" do
    with_env("ACTIVE_STORAGE_SERVICE" => nil, "AWS_BUCKET" => "listingpack-media") do
      assert_equal :cloud, StorageResolver.call
    end
  end

  test "resolver honors ACTIVE_STORAGE_SERVICE over bucket" do
    with_env("ACTIVE_STORAGE_SERVICE" => "local", "AWS_BUCKET" => "listingpack-media") do
      assert_equal :local, StorageResolver.call
    end
  end

  test "resolver falls back to local without bucket" do
    with_env("ACTIVE_STORAGE_SERVICE" => nil, "AWS_BUCKET" => nil) do
      assert_equal :local, StorageResolver.call
    end
  end

  test "development and production both call StorageResolver" do
    development = Rails.root.join("config/environments/development.rb").read
    production = Rails.root.join("config/environments/production.rb").read

    assert_match(/StorageResolver\.call/, development)
    assert_match(/StorageResolver\.call/, production)
    refute_match(/config\.active_storage\.service = :local/, development)
  end

  test "cloud S3 config only checksums when the API requires it" do
    yaml = Rails.root.join("config/storage.yml").read
    assert_match(/request_checksum_calculation:\s*"when_required"/, yaml)
    assert_match(/response_checksum_validation:\s*"when_required"/, yaml)
  end

  test "aws checksum initializer forces when_required for every S3 client" do
    source = Rails.root.join("config/initializers/aws_s3_checksums.rb").read
    assert_match(/request_checksum_calculation:\s*"when_required"/, source)
    assert_match(/response_checksum_validation:\s*"when_required"/, source)
  end

  private
    def with_env(pairs)
      previous = pairs.keys.index_with { |key| ENV[key] }
      pairs.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
end
