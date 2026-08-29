require "test_helper"

class RenderPosterBatchJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @listing = listings(:bgc_condo)
    @listing.user.update!(plan: "pro")
    @listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )
    @pack = @listing.content_packs.create!(language: @listing.language, status: "ready", stage: @listing.stage)
    GeneratedAsset.generation_keys(user: @listing.user).each do |key|
      @pack.generated_assets.create!(template_key: key, status: "pending")
    end
  end

  test "index 0 finishes first poster before enqueueing index 1" do
    stub_singleton(Images::ComposePoster, :new, ->(*) {
      Object.new.tap { |obj| obj.define_singleton_method(:call) { true } }
    }) do
      freeze_time do
        assert_enqueued_with(
          job: RenderPosterBatchJob,
          args: [ @pack.id, 1 ],
          at: RenderPosterBatchJob::NEXT_POSTER_WAIT.from_now
        ) do
          RenderPosterBatchJob.perform_now(@pack.id, 0)
        end
      end
    end

    first = @pack.generated_assets.find_by!(template_key: "just_listed")
    assert_equal "ready", first.status
    second = @pack.generated_assets.find_by!(template_key: "price_card")
    assert_equal "rendering", second.status
    assert_equal "pending", @pack.generated_assets.find_by!(template_key: "story").status
  end

  test "last index does not enqueue another job" do
    last = GeneratedAsset.batches(user: @listing.user).size - 1
    stub_singleton(Images::ComposePoster, :new, ->(*) {
      Object.new.tap { |obj| obj.define_singleton_method(:call) { true } }
    }) do
      assert_no_enqueued_jobs only: RenderPosterBatchJob do
        RenderPosterBatchJob.perform_now(@pack.id, last)
      end
    end
  end

  test "only one template key is rendered per job invocation" do
    rendered = []
    stub_singleton(Images::ComposePoster, :new, ->(pack, key, **) {
      rendered << key
      Object.new.tap { |obj| obj.define_singleton_method(:call) { true } }
    }) do
      RenderPosterBatchJob.perform_now(@pack.id, 0)
    end

    assert_equal [ "just_listed" ], rendered
  end

  test "disabled skips rendering and does not enqueue the next poster" do
    with_env("POSTER_RENDERER" => "off") do
      assert_no_enqueued_jobs only: RenderPosterBatchJob do
        RenderPosterBatchJob.perform_now(@pack.id, 0)
      end
    end

    @pack.generated_assets.each do |asset|
      assert_equal "failed", asset.reload.status
    end
    assert_match(/paused on this server/i, @pack.reload.error_message)
  end
end
