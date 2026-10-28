defmodule Hearth.ScreeningPolicy do
  # Forum and Chat can't call Hearth.Moderation, which depends on them so the screening rule lives here

  use Boundary, deps: [], exports: []
  alias Hearth.Common.T
  alias Oban.Job

  @worker "Hearth.Moderation.Worker.Screen"

  # A job still waiting covers edits made before it runs
  @unique [
    period: :infinity,
    keys: [:subject_type, :subject_id],
    states: ~w[available scheduled retryable]a
  ]

  @type subject_type :: :post | :reply | :message
  @type level :: :full | :reports | :none

  @spec screener() :: :off | atom()
  def screener, do: config(:screener)

  @spec on?() :: boolean()
  def on?, do: screener() != :off

  @spec image_floor?() :: boolean()
  def image_floor?, do: on?() and config(:image_floor) == :images

  @spec enqueue(subject_type(), T.id(), boolean() | (-> boolean()), (-> level())) ::
          :ok | {:error, term()}
  def enqueue(type, id, files?, level) when is_function(level, 0) do
    case applies?(files?, level) do
      true -> type |> job(id) |> Oban.insert() |> ok()
      false -> :ok
    end
  end

  @spec job(subject_type(), T.id()) :: Ecto.Changeset.t()
  def job(type, id) when type in ~w[post reply message]a and is_binary(id) do
    Job.new(%{subject_type: type, subject_id: id},
      worker: @worker,
      queue: :ai,
      max_attempts: 10,
      unique: @unique
    )
  end

  defp applies?(files?, level) do
    cond do
      not on?() -> false
      image_floor?() and answer(files?) -> true
      true -> level.() == :full
    end
  end

  defp answer(files?) when is_boolean(files?), do: files?
  defp answer(files?) when is_function(files?, 0), do: files?.()

  defp ok({:ok, _job}), do: :ok
  defp ok({:error, _reason} = error), do: error

  defp config(key), do: :hearth |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(key)
end
