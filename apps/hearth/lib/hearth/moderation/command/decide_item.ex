defmodule Hearth.Moderation.Command.DecideItem do
  alias Hearth.Accounts.User
  alias Hearth.Moderation.Action
  alias Hearth.Moderation.Command.SetContentStatus
  alias Hearth.Moderation.Item
  alias Hearth.Moderation.Lifecycle
  alias Hearth.Moderation.Screening
  alias Hearth.Moderation.Subject
  alias Hearth.Repo

  @spec execute(nil | User.t(), Item.t(), nil | Subject.t(), atom(), nil | String.t()) ::
          {:ok, Item.t()} | {:error, :invalid_transition | :stale | Ecto.Changeset.t()}
  def execute(moderator, %Item{} = item, subject, event, reason) do
    with {:ok, status} <- Lifecycle.next(item, event) do
      Repo.transact(fn -> write(moderator, item, subject, status, reason) end)
    end
  end

  defp write(moderator, item, subject, status, reason) do
    with {:ok, decided} <- Item.decide(item, status, get_in(moderator.id)),
         :ok <- change_content(subject, content_status(decided)),
         :ok <- outcome(decided),
         :ok <- log(moderator, item, decided, subject, reason) do
      {:ok, decided}
    end
  end

  defp content_status(%Item{status: :removed}), do: :removed
  defp content_status(%Item{status: :kept}), do: :published
  defp content_status(%Item{status: :pending, held: true}), do: :pending
  defp content_status(%Item{status: :pending}), do: :published
  defp content_status(%Item{status: :dismissed}), do: nil

  # A person's decision on a hold is what tells whether screening was right
  defp outcome(%Item{held: true, status: status} = item) when status in [:kept, :removed] do
    Screening.record_outcome(item.subject_type, item.subject_id, status)
  end

  defp outcome(%Item{}), do: :ok

  defp change_content(nil, _status), do: :ok
  defp change_content(_subject, nil), do: :ok
  defp change_content(subject, status), do: SetContentStatus.execute(subject, status)

  defp log(nil, _item, _decided, _subject, _reason), do: :ok

  defp log(moderator, item, decided, _subject, reason) do
    case action_for(item.status, decided.status) do
      nil ->
        :ok

      action ->
        attrs = %Action{
          community_id: item.community_id,
          actor_id: moderator.id,
          target_id: item.author_id,
          action: action,
          subject_type: item.subject_type,
          subject_id: item.subject_id
        }

        with {:ok, _action} <- Action.insert(attrs, %{reason: reason}), do: :ok
    end
  end

  defp action_for(:pending, :kept), do: :kept
  defp action_for(:pending, :removed), do: :removed
  defp action_for(:removed, :pending), do: :restored
  defp action_for(_from, _to), do: nil
end
