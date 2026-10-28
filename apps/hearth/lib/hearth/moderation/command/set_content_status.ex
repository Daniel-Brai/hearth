defmodule Hearth.Moderation.Command.SetContentStatus do
  alias Hearth.Chat
  alias Hearth.Forum
  alias Hearth.Moderation.Subject

  @spec execute(Subject.t(), :published | :pending | :removed) ::
          :ok | {:error, Ecto.Changeset.t()}
  def execute(%Subject{content: %{status: status}}, status), do: :ok

  def execute(%Subject{type: :message, content: message}, status) do
    with {:ok, _message} <- Chat.moderate(message, status), do: :ok
  end

  def execute(%Subject{content: content}, status) do
    with {:ok, _content} <- Forum.moderate(content, status), do: :ok
  end
end
