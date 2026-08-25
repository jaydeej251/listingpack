module Prompts
  module WeeklyCalendar
    VERSION = "weekly_calendar_v1"

    module_function

    def system_prompt
      <<~PROMPT
        You write a 5-day Facebook content calendar for a Philippine real-estate agent who may not have a new listing this week.
        Output JSON only: {"posts":[{"day":"Monday","title":"...","body":"..."}]}
        Exactly 5 posts, Monday to Friday.
        No property addresses unless provided. No "stunning" or generic AI voice.
        Mix: neighborhood explainer, financing/Pag-IBIG myth, rent-vs-buy, just-sold-in-the-area style (generic), and an ask-me-anything / DM CTA.
        Taglish unless language says otherwise. Each body 70-120 words.
      PROMPT
    end

    def user_prompt(user:, focus_area:, language:)
      brand = user.brand_kit
      <<~PROMPT
        Agent: #{brand&.name}
        Phone: #{brand&.phone}
        Focus area: #{focus_area}
        Language: #{language}
        Voice samples: #{brand&.voice_samples.presence || "(none)"}
      PROMPT
    end
  end
end
