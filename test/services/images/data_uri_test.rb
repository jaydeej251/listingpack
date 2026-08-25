require "test_helper"

class ImagesDataUriTest < ActiveSupport::TestCase
  test "accepts a has_many attached collection by reading the first photo" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    uri = Images::DataUri.from_attachment(listing.photos)
    assert uri.start_with?("data:image/png;base64,")
  end

  test "accepts a single ActiveStorage::Attachment from photos.first" do
    listing = listings(:bgc_condo)
    listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )

    uri = Images::DataUri.from_attachment(listing.photos.first)
    assert uri.start_with?("data:image/png;base64,")
  end

  test "returns nil for blank" do
    assert_nil Images::DataUri.from_attachment(nil)
  end
end
