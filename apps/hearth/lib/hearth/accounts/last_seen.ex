defmodule Hearth.Accounts.LastSeen do
  use Hearth.Buffer, every: :timer.seconds(30)

  alias Ecto.UUID
  alias Hearth.Repo

  @impl Hearth.Buffer
  def flush(entries) do
    {ids, times} =
      entries
      |> Enum.map(fn {user_id, _value, seen_at, _updates} ->
        {UUID.dump!(user_id), DateTime.from_unix!(seen_at, :microsecond)}
      end)
      |> Enum.unzip()

    Repo.query!(
      """
      UPDATE accounts.users AS u SET last_seen_at = v.seen_at
      FROM unnest($1::uuid[], $2::timestamptz[]) AS v(id, seen_at)
      WHERE u.id = v.id AND (u.last_seen_at IS NULL OR u.last_seen_at < v.seen_at)
      """,
      [ids, times]
    )

    :ok
  end
end
