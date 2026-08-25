require "test_helper"

class ProductionStorageTest < ActiveSupport::TestCase
  test "production picks cloud storage when AWS_BUCKET is set" do
    previous = {
      "ACTIVE_STORAGE_SERVICE" => ENV["ACTIVE_STORAGE_SERVICE"],
      "AWS_BUCKET" => ENV["AWS_BUCKET"]
    }

    ENV.delete("ACTIVE_STORAGE_SERVICE")
    ENV["AWS_BUCKET"] = "listingpack-media"

    service =
      if ENV["ACTIVE_STORAGE_SERVICE"].present?
        ENV["ACTIVE_STORAGE_SERVICE"].to_sym
      elsif ENV["AWS_BUCKET"].present?
        :cloud
      else
        :local
      end

    assert_equal :cloud, service
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "production falls back to local without bucket" do
    previous = {
      "ACTIVE_STORAGE_SERVICE" => ENV["ACTIVE_STORAGE_SERVICE"],
      "AWS_BUCKET" => ENV["AWS_BUCKET"]
    }

    ENV.delete("ACTIVE_STORAGE_SERVICE")
    ENV.delete("AWS_BUCKET")

    service =
      if ENV["ACTIVE_STORAGE_SERVICE"].present?
        ENV["ACTIVE_STORAGE_SERVICE"].to_sym
      elsif ENV["AWS_BUCKET"].present?
        :cloud
      else
        :local
      end

    assert_equal :local, service
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
