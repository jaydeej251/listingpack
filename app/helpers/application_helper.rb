module ApplicationHelper
  def peso(amount)
    return "Price on request" if amount.blank?

    "₱#{number_with_delimiter(amount.to_i)}"
  end

  def plan_badge(user)
    user.pro? ? "Pro" : "Free"
  end

  def quota_copy(user)
    if user.pro?
      "Pro · unlimited packs"
    else
      "#{user.remaining_packs} of #{User::FREE_PACKS_PER_MONTH} free packs left this month"
    end
  end

  def quota_fraction(user)
    return nil if user.pro?

    used = User::FREE_PACKS_PER_MONTH - user.remaining_packs
    [ used, User::FREE_PACKS_PER_MONTH ]
  end

  # Browser confirm before spending a Free pack. Always states remaining credits,
  # never "1 of 3" which reads as "you have 1 left."
  def pack_credit_confirm(user)
    return nil unless user.free?
    return nil unless user.can_generate_pack?

    left = user.remaining_packs
    cap = User::FREE_PACKS_PER_MONTH
    after = left - 1
    "This uses 1 pack credit. You have #{left} of #{cap} left this month" \
      "#{after.positive? ? " — #{after} will remain" : " — this is your last free pack"}" \
      ". Listing packs and This week share the same quota. Continue?"
  end

  def field_classes(record, attribute)
    classes = "field"
    classes += " field-invalid" if record.errors[attribute].any?
    classes
  end

  def field_error(record, attribute)
    return if record.errors[attribute].blank?

    tag.p record.errors[attribute].first, class: "field-hint-error"
  end

  def pack_pill_class(listing)
    case listing.pack_status
    when "ready" then "pill pill-ready"
    when "generating" then "pill pill-generating"
    when "failed" then "pill pill-failed"
    else "pill pill-draft"
    end
  end

  def studio_home_path
    return admin_users_path if current_user&.admin?

    authenticated? ? listings_path : root_path
  end

  def nav_link_class(active)
    active ? "text-clay" : "text-navy/80 hover:text-clay"
  end

  def listing_owner?(listing)
    current_user&.id == listing.user_id
  end

  def viewing_as_admin?(owner)
    current_user&.admin? && current_user.id != owner.id
  end

  def admin_quota_summary(user)
    if user.pro?
      "unlimited packs"
    else
      "#{user.packs_count_in_period} of #{User::FREE_PACKS_PER_MONTH} packs used"
    end
  end

  def listing_public_url(listing)
    public_listing_url(listing.share_token)
  end

  def facebook_sharer_url(url)
    "https://www.facebook.com/sharer/sharer.php?u=#{ERB::Util.url_encode(url)}"
  end

  def whatsapp_share_url(message)
    "https://wa.me/?text=#{ERB::Util.url_encode(message)}"
  end

  def listing_whatsapp_message(listing)
    "#{listing.share_text}. #{listing_public_url(listing)}"
  end
end
