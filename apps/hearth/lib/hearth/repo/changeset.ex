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

  @type offset :: {pos_integer(), :second | :minute | :hour | :day}

  # Keeps a date and time inside a window measured from now, such as
  # `after: {1, :minute}, before: {30, :day}`. Either side can be left out
  @spec validate_from_now(Changeset.t(), atom(), after: offset(), before: offset()) ::
          Changeset.t()
  def validate_from_now(changeset, field, opts) do
    validate_change(changeset, field, fn ^field, at ->
      now = DateTime.utc_now()

      Enum.reject(
        [too_soon(field, at, now, opts[:after]), too_late(field, at, now, opts[:before])],
        &is_nil/1
      )
    end)
  end

  defp too_soon(_field, _at, _now, nil), do: nil

  defp too_soon(field, at, now, {amount, unit} = offset) do
    if DateTime.before?(at, DateTime.add(now, amount, unit)),
      do: {field, "must be at least #{span(offset)} from now"}
  end

  defp too_late(_field, _at, _now, nil), do: nil

  defp too_late(field, at, now, {amount, unit} = offset) do
    if DateTime.after?(at, DateTime.add(now, amount, unit)),
      do: {field, "must be within #{span(offset)}"}
  end

  defp span({1, unit}), do: "1 #{unit}"
  defp span({amount, unit}), do: "#{amount} #{unit}s"

  defp message(opts, default, message_opts) do
    case Keyword.get(opts, :message, default) do
      {message, extra} when is_binary(message) and is_list(extra) ->
        {message, Keyword.merge(message_opts, extra)}

      message when is_binary(message) ->
        {message, message_opts}
    end
  end
end
