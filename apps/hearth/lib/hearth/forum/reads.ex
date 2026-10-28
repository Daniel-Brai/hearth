defmodule Hearth.Forum.Reads do
  # Marks go through Hearth.Buffer so only the latest per person and post is written

  use Hearth.Buffer, every: :timer.seconds(10)

  import Ecto.Query

  alias Hearth.Forum.PostRead
  alias Hearth.Repo

  @impl Hearth.Buffer
  def flush(entries) do
    rows =
      for {{user_id, post_id}, reply_count, seen_at, _updates} <- entries do
        %{
          user_id: user_id,
          post_id: post_id,
          seen_reply_count: reply_count,
          last_seen_at: DateTime.from_unix!(seen_at, :microsecond)
        }
      end

    # Each node flushes on its own, so a later read from another node must not be undone
    newer =
      from r in PostRead,
        update: [
          set: [
            last_seen_at: fragment("EXCLUDED.last_seen_at"),
            seen_reply_count: fragment("EXCLUDED.seen_reply_count")
          ]
        ],
        where: r.last_seen_at < fragment("EXCLUDED.last_seen_at")

    Repo.insert_all(PostRead, rows, on_conflict: newer, conflict_target: [:user_id, :post_id])

    :ok
  end
end
