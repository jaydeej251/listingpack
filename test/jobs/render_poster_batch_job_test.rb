require "test_helper"

class RenderPosterBatchJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @listing = listings(:bgc_condo)
    @listing.photos.attach(
      io: File.open(Rails.root.join("public/icon.png")),
      filename: "listing.png",
      content_type: "image/png"
    )
    @pack = @listing.content_packs.create!(language: @listing.language, status: "ready", stage: @listing.stage)
    GeneratedAsset.generation_keys.each do |key|
      @pack.generated_assets.create!(template_key: key, status: "pending")
    end
  end

  test "index 0 finishes first poster before enqueueing index 1" do
    stub_singleton(Images::Chrome, :path, nil) do
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
    assert_equal "failed", first.status
    second = @pack.generated_assets.find_by!(template_key: "price_card")
    assert_equal "rendering", second.status
    assert_equal "pending", @pack.generated_assets.find_by!(template_key: "story").status
  end

  test "last index does not enqueue another job" do
    last = GeneratedAsset.batches.size - 1
    stub_singleton(Images::Chrome, :path, nil) do
      assert_no_enqueued_jobs only: RenderPosterBatchJob do
        RenderPosterBatchJob.perform_now(@pack.id, last)
      end
    end
  end

  test "only one template key is rendered per job invocation" do
    rendered = []
    stub_singleton(Images::Chrome, :path, nil) do
      stub_singleton(Images::RenderPosterBatch, :new, ->(pack, keys) {
        rendered << keys.dup
        Object.new.tap { |obj| obj.define_singleton_method(:call) { { errors: [], rendered: 0 } } }
      }) do
        RenderPosterBatchJob.perform_now(@pack.id, 0)
      end
    end

    assert_equal [ [ "just_listed" ] ], rendered
  end

  test "disabled skips chrome and does not enqueue the next poster" do
    chrome_opened = false
    stub_singleton(Images::PosterBrowser, :open, ->(*) { chrome_opened = true }) do
      with_env("POSTER_RENDER_ENABLED" => "false") do
        assert_no_enqueued_jobs only: RenderPosterBatchJob do
          RenderPosterBatchJob.perform_now(@pack.id, 0)
        end
      end
    end

    refute chrome_opened
    @pack.generated_assets.each do |asset|
      assert_equal "failed", asset.reload.status
    end
    assert_match(/paused on this server/i, @pack.reload.error_message)
  end
end
