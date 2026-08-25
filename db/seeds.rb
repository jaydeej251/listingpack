pro = User.find_or_create_by!(email_address: "agent@listingpack.local") do |user|
  user.password = "password123"
  user.plan = "pro"
end
pro.update!(password: "password123", plan: "pro") unless pro.pro?

pro.brand_kit.update!(
  display_name: "Maria Santos",
  phone: "0917 000 0000",
  facebook_name: "Maria Santos Realty",
  voice_samples: "Just listed sa BGC mga sis — parking included, DM for viewing. Seller needs a 60-day close."
)

listing = pro.listings.find_or_initialize_by(title: "2BR at The Fort Residences")
listing.assign_attributes(
  location: "BGC, Taguig",
  price_amount: 12_500_000,
  bedrooms: 2,
  bathrooms: 2,
  floor_area: 58,
  amenities: "24h security, near High Street",
  notes: "Seller relocating, 60-day close",
  language: "taglish",
  status: "ready",
  stage: "listed",
  listing_type: "for_sale",
  financing: "pag_ibig",
  parking: true,
  association_dues: "₱8,500 / mo",
  near_transit: "BGC Bus",
  price_confirmed: true
)

unless listing.photos.attached?
  listing.photos.attach(
    io: File.open(Rails.root.join("public/icon.svg")),
    filename: "listing.svg",
    content_type: "image/svg+xml"
  )
end

listing.save!

pack = listing.content_packs.order(created_at: :desc).first
pack ||= listing.content_packs.create!(language: "taglish", status: "ready", stage: "listed")
pack.update!(
  status: "ready",
  facebook_caption: "Just listed sa BGC — 2BR, 58 sqm, may parking na. Seller needs a 60-day close. DM lang for viewing.",
  facebook_group_caption: "BGC 2BR for sale — parking included, Pag-IBIG OK. Serious buyers only.",
  marketplace_caption: "2BR condo for sale in BGC, Taguig. 58 sqm, parking, ₱12,500,000.",
  instagram_caption: "Golden hour sa The Fort Residences. 2BR · parking included. Link in bio.",
  facebook_ad_copy: "Just listed in BGC. 2BR, parking, Pag-IBIG welcome. Book a viewing today.",
  listing_description: "Bright 2BR at The Fort Residences in BGC. Parking included. Seller open to a 60-day close.",
  messenger_followup: "Hi po! Still available yung 2BR sa BGC. Free ba kayo this Saturday for a viewing?",
  seller_report: "Hi — week 1 update on The Fort Residences 2BR.\n\nReach is growing on Facebook. Two viewing requests so far. Buyers keep asking about parking and Pag-IBIG.\n\nRecommendation: hold the price this week and push Saturday open house."
)

GeneratedAsset::TEMPLATE_KEYS.each do |key|
  pack.generated_assets.find_or_create_by!(template_key: key)
end

begin
  GeneratedAsset::TEMPLATE_KEYS.each do |key|
    asset = pack.generated_assets.find_by!(template_key: key)
    next if asset.image.attached?

    Images::RenderTemplate.new(pack, key, watermark: false).call
  end
rescue Images::RenderTemplate::Error => e
  puts "Poster PNGs skipped (Chrome missing or render failed): #{e.message}"
end

free = User.find_or_create_by!(email_address: "free@listingpack.local") do |user|
  user.password = "password123"
  user.plan = "free"
end
free.update!(
  password: "password123",
  plan: "free",
  quota_period_start: Time.zone.today.beginning_of_month,
  packs_count_in_period: 1
)
free.brand_kit.update!(
  display_name: "Juan dela Cruz",
  phone: "0918 111 2222",
  facebook_name: "Juan Realty",
  voice_samples: "Pre-selling sa QC — flexible payment. DM for inventory."
)

puts "Demo logins:"
puts "  Pro:  agent@listingpack.local / password123  (ready pack on Listings)"
puts "  Free: free@listingpack.local / password123  (1 of 3 packs used — watermark path)"
puts "Posters need local Chrome/Chromium for PNG renders."
