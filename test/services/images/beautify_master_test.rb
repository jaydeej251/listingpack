require "test_helper"

class ImagesBeautifyMasterTest < ActiveSupport::TestCase
  setup do
    @listing = listings(:bgc_condo)
    @listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )
    @pack = @listing.content_packs.create!(language: @listing.language, status: "ready", stage: @listing.stage)
  end

  test "skips when beauty is disabled" do
    client = Ai::ImageClient.new
    stub_singleton(client, :enabled?, false) do
      result = Images::BeautifyMaster.new(@pack, client: client).call
      assert result[:skipped]
      assert_not @pack.beauty_master.attached?
    end
  end

  test "attaches master png from openai edit and records generation" do
    captured = {}
    client = Object.new
    client.define_singleton_method(:enabled?) { true }
    client.define_singleton_method(:max_photos) { 6 }
    client.define_singleton_method(:model) { "gpt-image-1.5" }
    client.define_singleton_method(:edit) do |images:, prompt:, **|
      captured[:images] = images
      captured[:prompt] = prompt
      {
        png_bytes: "beauty-png",
        model: "gpt-image-1.5",
        input_tokens: 11,
        output_tokens: 22
      }
    end

    result = Images::BeautifyMaster.new(@pack, client: client).call

    assert result[:ok], "expected ok, got #{result.inspect}"
    assert_operator captured[:images].size, :>=, 1
    assert_includes captured[:prompt], "highly converting"
    assert @pack.beauty_master.attached?
    assert_equal "image/png", @pack.beauty_master.content_type
    gen = @pack.generations.find_by(kind: "image_beauty")
    assert gen
    assert_equal "gpt-image-1.5", gen.model
    assert_equal 11, gen.input_tokens
  end

  test "openai failure records generation and leaves master blank for compositor fallback" do
    client = Object.new
    client.define_singleton_method(:enabled?) { true }
    client.define_singleton_method(:max_photos) { 6 }
    client.define_singleton_method(:model) { "gpt-image-1.5" }
    client.define_singleton_method(:edit) { |**| raise Ai::ImageClient::Error, "rate limited" }

    result = Images::BeautifyMaster.new(@pack, client: client).call

    assert_not result[:ok]
    assert_equal "rate limited", result[:error]
    assert_not @pack.beauty_master.attached?
    gen = @pack.generations.find_by(kind: "image_beauty")
    assert_includes gen.error_message, "rate limited"
  end

  test "second call is a no-op when master already attached" do
    @pack.beauty_master.attach(
      io: StringIO.new("existing"),
      filename: "beauty_master.png",
      content_type: "image/png",
      identify: false
    )
    called = false
    client = Object.new
    client.define_singleton_method(:enabled?) { true }
    client.define_singleton_method(:edit) { |**| called = true; raise "should not call" }

    result = Images::BeautifyMaster.new(@pack, client: client).call
    assert result[:skipped]
    assert_not called
  end
end
