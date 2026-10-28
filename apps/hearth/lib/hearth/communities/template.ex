defmodule Hearth.Communities.Template do
  @enforce_keys ~w[id label icon description rooms placeholder]a
  defstruct ~w[id label icon description category rooms voice placeholder]a

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t(),
          icon: String.t(),
          description: String.t(),
          category: nil | String.t(),
          rooms: [String.t()],
          voice: nil | String.t(),
          placeholder: %{name: String.t(), tagline: String.t()}
        }

  @templates [
    %{
      id: "club",
      label: "Club or hobby",
      icon: "sparkles",
      description: "People who share an interest",
      category: "hobbies",
      rooms: ~w[general show-and-tell],
      voice: "Hangout",
      placeholder: %{name: "Plant Parents", tagline: "Keeping houseplants alive together"}
    },
    %{
      id: "local",
      label: "Local group",
      icon: "map",
      description: "Neighbours, meetups and things to do nearby",
      category: "local",
      rooms: ~w[general events],
      voice: "Planning call",
      placeholder: %{name: "Yaba Neighbours", tagline: "News, events and help around Yaba"}
    },
    %{
      id: "creator",
      label: "Creator and fans",
      icon: "star",
      description: "A home for your audience",
      category: "art",
      rooms: ~w[general fan-art],
      voice: "Live hangout",
      placeholder: %{name: "Studio Ade", tagline: "Behind the scenes with Ade's comics"}
    },
    %{
      id: "class",
      label: "Class or study group",
      icon: "bulb",
      description: "Learn together, ask questions, share notes",
      category: "learning",
      rooms: ~w[general homework-help],
      voice: "Study room",
      placeholder: %{
        name: "Data Science Cohort 4",
        tagline: "Notes, questions and study sessions"
      }
    },
    %{
      id: "support",
      label: "Support group",
      icon: "helpful",
      description: "A kind, moderated space to talk",
      category: "support",
      rooms: ~w[general small-wins],
      voice: "Check in",
      placeholder: %{name: "New Parents Lagos", tagline: "Sleepless and supported"}
    },
    %{
      id: "oss",
      label: "Open source project",
      icon: "code",
      description: "Help, ideas and releases for your project",
      category: "tech",
      rooms: ~w[general help contributors],
      voice: "Office hours",
      placeholder: %{name: "Feedbase", tagline: "A self hosted RSS reader"}
    },
    %{
      id: "blank",
      label: "Start from scratch",
      icon: "plus",
      description: "Just a feed and #general",
      category: nil,
      rooms: ["general"],
      voice: nil,
      placeholder: %{name: "Your community", tagline: "What it is about, in a line"}
    }
  ]

  @ids Enum.map(@templates, & &1.id)

  @spec ids() :: [String.t()]
  def ids, do: @ids

  @spec all() :: [t()]
  def all, do: Enum.map(@templates, &struct!(__MODULE__, &1))

  @spec get(String.t()) :: t()
  def get(id) do
    attrs = Enum.find(@templates, &(&1.id == id)) || List.last(@templates)

    struct!(__MODULE__, attrs)
  end
end
