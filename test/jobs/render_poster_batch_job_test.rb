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

  test "batch 0 renders core keys and enqueues batch 1" do
    stub_singleton(Images::Chrome, :path, nil) do
      assert_enqueued_with(job: RenderPosterBatchJob, args: [ @pack.id, 1 ]) do
        RenderPosterBatchJob.perform_now(@pack.id, 0)
      end
    end

    core = @pack.generated_assets.where(template_key: GeneratedAsset::CORE_TEMPLATE_KEYS)
    assert core.all?(&:failed?)
  end

  test "batch 1 does not enqueue another batch" do
    stub_singleton(Images::Chrome, :path, nil) do
      assert_no_enqueued_jobs only: RenderPosterBatchJob do
        RenderPosterBatchJob.perform_now(@pack.id, 1)
      end
    end
  end
end
