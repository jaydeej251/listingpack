require "test_helper"

class BrandKitTest < ActiveSupport::TestCase
  test "display name is required on update" do
    kit = brand_kits(:one)
    kit.display_name = ""
    assert_not kit.valid?
    assert_includes kit.errors[:display_name], "can't be blank"
  end

  test "name falls back to email when display name blank on a new kit" do
    user = users(:one)
    kit = BrandKit.new(user: user, display_name: nil)
    assert_equal user.email_address, kit.name
  end
end
