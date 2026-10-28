defmodule Hearth.Forum.KindLibrary do
  # Keep in sync with KIND_LIB and TEMPLATES in the web app's domain/catalog.ts

  @kinds %{
    "question" => %{
      label: "Question",
      icon: "question",
      hue: "blue",
      title_hint: "What do you need help with?",
      body_hint:
        "Say what you tried and what happened. Add photos or links if they help, @mention people and add #tags.",
      description: "Ask for help. Mark the reply that solved it.",
      answers: true
    },
    "discussion" => %{
      label: "Discussion",
      icon: "chat",
      hue: "violet",
      title_hint: "What do you want to talk about?",
      body_hint:
        "Write as much or as little as you like. Formatting, @mentions and #tags all work here.",
      description: "Open ended talk, opinions and ideas."
    },
    "show" => %{
      label: "Show and tell",
      icon: "sparkles",
      hue: "orange",
      title_hint: "What did you make?",
      body_hint: "Show it off. Add screenshots, a link and what you learned along the way.",
      description: "Share something you built."
    },
    "announcement" => %{
      label: "Announcement",
      icon: "megaphone",
      hue: "green",
      title_hint: "What is the news?",
      body_hint: "Releases, events and changes people should know about.",
      description: "News from the people who run it.",
      postable: false
    },
    "bug" => %{
      label: "Bug report",
      icon: "bug",
      hue: "red",
      title_hint: "What went wrong?",
      body_hint:
        "Steps to reproduce, what you expected, what happened instead, and your version.",
      description: "Something broken. Mark the reply with the fix.",
      answers: true
    },
    "idea" => %{
      label: "Idea",
      icon: "bulb",
      hue: "yellow",
      title_hint: "What would make it better?",
      body_hint: "Describe the problem first, then the idea. Mockups welcome.",
      description: "Feature requests and suggestions."
    },
    "rec" => %{
      label: "Recommendation",
      icon: "star",
      hue: "pink",
      title_hint: "What should people read, watch or try?",
      body_hint:
        "Say what it is, who it is for and why it stayed with you. No spoilers without a warning.",
      description: "Something you think others will love."
    },
    "meetup" => %{
      label: "Meetup",
      icon: "calendar",
      hue: "orange",
      title_hint: "Where and when are you meeting?",
      body_hint: "Place, time, what to bring and how people find you.",
      description: "Plan a get together, online or in person."
    },
    "photo" => %{
      label: "Photo",
      icon: "image",
      hue: "violet",
      title_hint: "What did you capture?",
      body_hint: "Paste or drop your photos, then say a bit about them.",
      description: "Share pictures and the story behind them."
    },
    "intro" => %{
      label: "Introduction",
      icon: "users",
      hue: "green",
      title_hint: "Tell us about yourself",
      body_hint: "Where you are, what brought you here and what you hope to get out of it.",
      description: "Say hello when you are new."
    }
  }

  @templates %{
    "club" => ~w[discussion question photo meetup announcement],
    "local" => ~w[meetup question discussion intro announcement],
    "creator" => ~w[announcement discussion photo question],
    "class" => ~w[question discussion rec announcement],
    "support" => ~w[intro discussion question announcement],
    "oss" => ~w[question discussion show bug idea announcement],
    "blank" => ~w[discussion question announcement]
  }

  @spec keys_for_template(String.t()) :: [String.t()]
  def keys_for_template(template), do: Map.get(@templates, template, @templates["blank"])

  @spec for_template(String.t()) :: [map()]
  def for_template(template) do
    keys = Map.get(@templates, template, @templates["blank"])

    keys
    |> Enum.with_index()
    |> Enum.map(fn {key, position} ->
      @kinds
      |> Map.fetch!(key)
      |> Map.merge(%{key: key, position: position})
    end)
  end
end
