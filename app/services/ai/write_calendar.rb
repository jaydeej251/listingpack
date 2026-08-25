module Ai
  class WriteCalendar
    def initialize(calendar)
      @calendar = calendar
      @user = calendar.user
      @client = Ai::Client.new
    end

    def call
      if @client.configured?
        from_openai
      else
        { posts: fallback_posts, model: "template_fallback", prompt_version: ::Prompts::WeeklyCalendar::VERSION }
      end
    end

    private
      def from_openai
        result = @client.chat(
          messages: [
            { role: "system", content: ::Prompts::WeeklyCalendar.system_prompt },
            { role: "user", content: ::Prompts::WeeklyCalendar.user_prompt(user: @user, focus_area: @calendar.focus_area, language: "taglish") }
          ]
        )
        payload = JSON.parse(result[:text])
        {
          posts: payload["posts"],
          model: result[:model],
          input_tokens: result[:input_tokens],
          output_tokens: result[:output_tokens],
          prompt_version: ::Prompts::WeeklyCalendar::VERSION
        }
      end

      def fallback_posts
        area = @calendar.focus_area.presence || "Metro Manila"
        name = @user.brand_kit&.name
        [
          { "day" => "Monday", "title" => "Neighborhood analog", "body" => "If you work in #{area} and hate the commute, tell me your budget and I'll map what ₱X/month actually buys this week — condo vs townhouse vs house. DM #{name}." },
          { "day" => "Tuesday", "title" => "Pag-IBIG myth", "body" => "Pag-IBIG is not only for minimum wage. If you have a consistent income trail, we can run the numbers before you tour anything in #{area}. Send me your take-home and I'll tell you a realistic ceiling." },
          { "day" => "Wednesday", "title" => "Rent vs buy", "body" => "Still renting in #{area}? Compare 1 year of rent vs a starter DP. Not a lecture — a spreadsheet. Comment RENT and I'll send the breakdown." },
          { "day" => "Thursday", "title" => "What sold nearby", "body" => "Quiet week on new listings doesn't mean a quiet market. Units in #{area} still moved when the price, parking, and closing timeline were honest. If you're listing, I'll tell you what buyers actually asked last month." },
          { "day" => "Friday", "title" => "Ask me anything", "body" => "No new listing today — still working. Ask about #{area} condos, assoc dues, flood-prone pockets, or viewing etiquette. I'll answer in the comments or DM." }
        ]
      end
  end
end
