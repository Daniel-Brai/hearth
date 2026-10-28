defmodule Hearth.TranscriptionPolicy do
  # Off unless the operator turns it on since a transcript is a lasting record

  use Boundary, deps: [], exports: []

  alias Hearth.Common.T
  alias Oban.Job

  @modes %{"off" => :off, "local" => :local}

  # Voice can't call Hearth.Transcripts, which depends on it, so the job is named here
  @worker "Hearth.Transcripts.Worker.Transcribe"

  @type mode :: :off | :local

  @spec load!() :: mode()
  def load!, do: mode()

  @spec mode() :: mode()
  def mode, do: :hearth |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(:mode) |> parse!()

  @spec on?() :: boolean()
  def on?, do: mode() != :off

  @spec check() :: :ok | {:error, :transcription_off}
  def check, do: if(on?(), do: :ok, else: {:error, :transcription_off})

  @spec enqueue(T.id()) :: :ok | {:error, term()}
  def enqueue(recording_id) do
    case on?() do
      true -> recording_id |> job() |> Oban.insert() |> ok()
      false -> :ok
    end
  end

  @spec job(T.id()) :: Ecto.Changeset.t()
  def job(recording_id) when is_binary(recording_id) do
    Job.new(%{recording_id: recording_id},
      worker: @worker,
      queue: :transcribe,
      max_attempts: 5,
      unique: [period: :infinity, keys: [:recording_id], states: :incomplete]
    )
  end

  @spec parse!(nil | atom() | String.t()) :: mode()
  def parse!(nil), do: :off
  def parse!(value) when is_atom(value), do: value |> Atom.to_string() |> parse!()

  def parse!(value) when is_binary(value) do
    name = value |> String.trim() |> String.downcase()

    case name do
      "" ->
        :off

      name ->
        Map.get(@modes, name) ||
          raise ArgumentError,
                "TRANSCRIPTION has #{name}, which this release doesn't know. Use " <>
                  (@modes |> Map.keys() |> Enum.sort(:desc) |> Enum.join(", "))
    end
  end

  defp ok({:ok, _job}), do: :ok
  defp ok({:error, _reason} = error), do: error
end
