require "test_helper"

class AppHostTest < ActiveSupport::TestCase
  test "strips scheme and path from APP_HOST" do
    with_env("APP_HOST" => "https://listingpack.com/unused") do
      assert_equal "listingpack.com", AppHost.host
      assert_equal "https://listingpack.com", AppHost.origin
    end
  end

  test "localhost origin stays http" do
    with_env("APP_HOST" => "localhost:3000") do
      assert_equal "http://localhost:3000", AppHost.origin
    end
  end

  test "allowed hosts include ADDITIONAL_HOSTS" do
    with_env("APP_HOST" => "listingpack.com", "ADDITIONAL_HOSTS" => "www.listingpack.com, https://preview.example.com") do
      assert_equal %w[listingpack.com www.listingpack.com preview.example.com], AppHost.allowed
    end
  end

  test "production config is env-driven instead of onrender" do
    source = Rails.root.join("config/environments/production.rb").read

    assert_match(/AppHost/, source)
    refute_match(/onrender/, source)
  end

  test "PayMongo return URLs follow APP_HOST even when a scheme is pasted" do
    with_env("APP_HOST" => "https://listingpack.com", "PAYMONGO_SECRET_KEY" => "sk_test_x") do
      paymongo = Billing::Paymongo.new

      assert_equal "https://listingpack.com/billing?paid=1", paymongo.send(:success_url)
      assert_equal "https://listingpack.com/billing?canceled=1", paymongo.send(:cancel_url)
    end
  end

  test "db:migrate is hooked to load Solid schemas for Hatchbox" do
    source = Rails.root.join("lib/tasks/prepare_solid.rake").read

    assert_match(/db:migrate/, source)
    assert_match(/prepare_solid/, source)
  end
end
