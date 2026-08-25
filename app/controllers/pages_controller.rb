class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ home privacy terms guide publishing ]

  def home
  end

  def privacy
  end

  def terms
  end

  def guide
  end

  def publishing
  end
end
