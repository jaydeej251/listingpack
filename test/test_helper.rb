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
  end
end
