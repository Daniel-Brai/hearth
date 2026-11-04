defmodule Hearth.Repo.Changeset do
  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common

  @spec validate_email(Changeset.t(), atom(), keyword()) :: Changeset.t()
  def validate_email(changeset, field, opts \\ []) do
    validate_change(changeset, field, fn ^field, value ->
      if not is_binary(value) do
        raise ArgumentError,
              "validate_email/3 expects changes to be strings, received: #{inspect(value)} for field `#{field}`"
      end

      cond do
        not EmailChecker.valid?(value) ->
          [{field, message(opts, "is not a valid email", validation: :email)}]

        Common.mail_domain_status(value) == :unreachable ->
          [{field, message(opts, "can't receive email", validation: :email)}]

        true ->
          []
      end
    end)
  end

  # Far enough ahead to be worth waiting for and no more than a month out
  @spec validate_send_at(Changeset.t(), atom()) :: Changeset.t()
  def validate_send_at(changeset, field \\ :send_at) do
    validate_change(changeset, field, fn ^field, at ->
      now = DateTime.utc_now()

      cond do
        DateTime.before?(at, DateTime.add(now, 1, :minute)) ->
          [{field, "must be at least a minute from now"}]

        DateTime.after?(at, DateTime.add(now, 30, :day)) ->
          [{field, "must be within 30 days"}]

        true ->
          []
      end
    end)
  end

  defp message(opts, default, message_opts) do
    case Keyword.get(opts, :message, default) do
      {message, extra} when is_binary(message) and is_list(extra) ->
        {message, Keyword.merge(message_opts, extra)}

      message when is_binary(message) ->
        {message, message_opts}
    end
  end
end
