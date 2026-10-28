defmodule Hearth.Forum.PostReaction do
  use Hearth.Repo.Schema, prefix: "forum", primary_key: false

  alias Hearth.Common.T

  schema "post_reactions" do
    field :post_id, Ecto.UUID, primary_key: true
    field :user_id, Ecto.UUID, primary_key: true
    field :emoji, :string, primary_key: true

    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{post_id: T.id(), user_id: T.id(), emoji: String.t()}
  @type summary :: %{emoji: String.t(), count: pos_integer(), mine: boolean()}

  @spec toggle(T.id(), T.id(), String.t()) :: :added | :removed
  def toggle(post_id, user_id, emoji) do
    key = [post_id: post_id, user_id: user_id, emoji: emoji]

    case get(key) do
      nil ->
        __MODULE__
        |> struct!(key)
        |> Repo.insert!()

        :added

      %__MODULE__{} = reaction ->
        Repo.delete!(reaction)
        :removed
    end
  end

  # Each emoji once per post with how many people used it, in the order first used
  # A signed out viewer has none of their own
  @spec summaries([T.id()], nil | T.id()) :: %{T.id() => [summary()]}
  def summaries(post_ids, user_id) when is_list(post_ids) do
    query =
      from r in __MODULE__,
        where: r.post_id in ^post_ids,
        group_by: [r.post_id, r.emoji],
        order_by: [asc: min(r.inserted_at), asc: r.emoji],
        select:
          {r.post_id,
           %{
             emoji: r.emoji,
             count: count(),
             mine:
               fragment("coalesce(bool_or(? = ?), false)", r.user_id, type(^user_id, Ecto.UUID))
           }}

    query
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @spec count(T.id(), String.t()) :: non_neg_integer()
  def count(post_id, emoji) do
    __MODULE__
    |> where(post_id: ^post_id, emoji: ^emoji)
    |> Repo.aggregate(:count)
  end
end
