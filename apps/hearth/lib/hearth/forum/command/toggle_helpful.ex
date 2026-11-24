defmodule Hearth.Forum.Command.ToggleHelpful do
  alias Hearth.Accounts.User
  alias Hearth.Forum.HelpfulMark
  alias Hearth.Forum.Post
  alias Hearth.Forum.Reply
  alias Hearth.Repo

  @spec execute(User.t(), Post.t() | Reply.t()) :: {:ok, :marked | :unmarked}
  def execute(%User{} = user, subject) do
    {schema, key} = target(subject)
    mark = [{:user_id, user.id}, {key, subject.id}]

    Repo.transact(fn ->
      case HelpfulMark.get(mark) do
        nil ->
          Repo.insert!(struct!(HelpfulMark, mark))
          :ok = schema.count_helpful(subject.id, 1)
          {:ok, :marked}

        %HelpfulMark{} = existing ->
          Repo.delete!(existing)
          :ok = schema.count_helpful(subject.id, -1)
          {:ok, :unmarked}
      end
    end)
  end

  defp target(%Post{}), do: {Post, :post_id}
  defp target(%Reply{}), do: {Reply, :reply_id}
end
