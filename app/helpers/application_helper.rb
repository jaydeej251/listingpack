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
    authenticated? ? listings_path : root_path
  end

  def nav_link_class(active)
    active ? "text-clay" : "text-navy/80 hover:text-clay"
  end
end
