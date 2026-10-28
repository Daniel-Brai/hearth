defmodule Hearth.Moderation.Command.SetLevel do
  alias Hearth.Accounts.User
  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias Hearth.Communities.Room
  alias Hearth.Moderation.Action
  alias Hearth.Repo

  @spec execute(User.t(), Community.t() | Room.t(), nil | Community.level()) ::
          {:ok, Community.t() | Room.t()} | {:error, Ecto.Changeset.t()}
  def execute(%User{} = user, place, level) do
    {community_id, subject_type} =
      case place do
        %Community{id: id} -> {id, :community}
        %Room{community_id: id} -> {id, :room}
      end

    action = %Action{
      community_id: community_id,
      actor_id: user.id,
      action: :changed,
      subject_type: subject_type,
      subject_id: place.id
    }

    metadata = %{
      "from" => level_name(place.moderation),
      "to" => level_name(level)
    }

    Repo.transact(fn ->
      with {:ok, place} <- Communities.put_moderation(place, level),
           {:ok, _action} <- Action.insert(action, %{metadata: metadata}) do
        {:ok, place}
      end
    end)
  end

  defp level_name(nil), do: nil
  defp level_name(level), do: Atom.to_string(level)
end
