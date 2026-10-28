defmodule Hearth.Moderation.Command.ModerateContent do
  alias Hearth.Accounts.User
  alias Hearth.Moderation.Action
  alias Hearth.Moderation.Command.SetContentStatus
  alias Hearth.Moderation.Subject
  alias Hearth.Repo

  @spec execute(User.t(), Subject.t(), :removed | :published, nil | String.t()) ::
          {:ok, Subject.t()} | {:error, Ecto.Changeset.t()}
  def execute(%User{} = moderator, %Subject{} = subject, status, reason) do
    action = %Action{
      community_id: subject.community_id,
      actor_id: moderator.id,
      target_id: subject.author_id,
      action: if(status == :removed, do: :removed, else: :restored),
      subject_type: subject.type,
      subject_id: subject.content.id
    }

    Repo.transact(fn ->
      with :ok <- SetContentStatus.execute(subject, status),
           {:ok, _action} <- Action.insert(action, %{reason: reason}) do
        {:ok, %{subject | content: %{subject.content | status: status}}}
      end
    end)
  end
end
