ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Temporarily replace a singleton method (Minitest has no Class#stub by default).
    def stub_singleton(object, method_name, value_or_callable)
      singleton = object.singleton_class
      original = object.method(method_name)
      singleton.define_method(method_name) do |*args, **kwargs, &block|
        value_or_callable.respond_to?(:call) ? value_or_callable.call(*args, **kwargs, &block) : value_or_callable
      end
      yield
    ensure
      singleton.define_method(method_name, original)
    end

    def without_env(*keys)
      previous = keys.index_with { |key| ENV[key] }
      keys.each { |key| ENV.delete(key) }
      yield
    ensure
      previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

    def with_env(vars)
      previous = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value.to_s }
      yield
    ensure
      previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end
end
