class RecoverStaleGenerationsJob < ApplicationJob
  queue_as :default

  def perform
    Packs::RecoverStaleGenerations.call
  end
end
