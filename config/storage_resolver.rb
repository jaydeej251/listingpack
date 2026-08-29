# Shared by development and production so local `.env` AWS_* hits the same
# R2/S3 service as Hatchbox. Test always stays on Disk (`config/environments/test.rb`).
module StorageResolver
  module_function

  def call
    if ENV["ACTIVE_STORAGE_SERVICE"].present?
      ENV["ACTIVE_STORAGE_SERVICE"].to_sym
    elsif ENV["AWS_BUCKET"].present?
      :cloud
    else
      :local
    end
  end
end
