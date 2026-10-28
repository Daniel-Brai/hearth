defmodule HearthWeb.Schema.Reaction do
  use JSV.Schema

  defschema %{
    title: "Reaction",
    type: :object,
    description: "One emoji on a message or post, in the order it was first used",
    required: [:emoji, :count, :mine],
    properties: %{
      emoji: string(),
      count: pos_integer(),
      mine: boolean(description: "The viewer is one of them, false signed out")
    }
  }
end
