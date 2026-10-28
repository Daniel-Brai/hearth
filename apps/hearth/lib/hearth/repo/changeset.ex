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

  defp message(opts, default, message_opts) do
    case Keyword.get(opts, :message, default) do
      {message, extra} when is_binary(message) and is_list(extra) ->
        {message, Keyword.merge(message_opts, extra)}

      message when is_binary(message) ->
        {message, message_opts}
    end
  end
end
