defmodule Hearth.Chat.Reaction do
  use Hearth.Repo.Schema, prefix: "chat", primary_key: false

  alias Hearth.Common.T

  schema "message_reactions" do
    field :message_id, Ecto.UUID, primary_key: true
    field :user_id, Ecto.UUID, primary_key: true
    field :emoji, :string, primary_key: true

    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{
          message_id: T.id(),
          user_id: T.id(),
          emoji: String.t()
        }

  @spec toggle(T.id(), T.id(), String.t()) :: :added | :removed
  def toggle(message_id, user_id, emoji) do
    key = [message_id: message_id, user_id: user_id, emoji: emoji]

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

  @type summary :: %{emoji: String.t(), count: pos_integer(), mine: boolean()}

  # Each emoji once per message with how many people used it, in the order first used
  @spec summaries([T.id()], T.id()) :: %{T.id() => [summary()]}
  def summaries(message_ids, user_id) when is_list(message_ids) do
    query =
      from r in __MODULE__,
        where: r.message_id in ^message_ids,
        group_by: [r.message_id, r.emoji],
        order_by: [asc: min(r.inserted_at), asc: r.emoji],
        select:
          {r.message_id,
           %{
             emoji: r.emoji,
             count: count(),
             mine: fragment("bool_or(? = ?)", r.user_id, type(^user_id, Ecto.UUID))
           }}

    query
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @spec count(T.id(), String.t()) :: non_neg_integer()
  def count(message_id, emoji) do
    __MODULE__
    |> where(message_id: ^message_id, emoji: ^emoji)
    |> Repo.aggregate(:count)
  end
end
