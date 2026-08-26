require "test_helper"
require Rails.root.join("config/database_pool")

class DatabasePoolTest < ActiveSupport::TestCase
  test "honors explicit DB_POOL" do
    with_env("DB_POOL" => "10", "RAILS_MAX_THREADS" => "2") do
      assert_equal 10, DatabasePool.size
    end
  end

  test "raises pool to Solid Queue minimum when threads are low" do
    with_env("DB_POOL" => nil, "RAILS_MAX_THREADS" => "2") do
      assert_equal 5, DatabasePool.size
    end
  end

  test "follows higher RAILS_MAX_THREADS" do
    with_env("DB_POOL" => nil, "RAILS_MAX_THREADS" => "8") do
      assert_equal 8, DatabasePool.size
    end
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
