defmodule Hearth.Voice.Captions do
  # Captions run Whisper on stretches of speech each peer hands over
  # They share the model with transcripts so any stretch over caption_limit is dropped
  # A missing caption is better than a backlog that slows the room

  alias Hearth.AI
  alias Hearth.Common.T
  alias Hearth.Media.TempFile
  alias Hearth.PubSub
  alias Hearth.Voice.TrackFile
  alias Hearth.Voice.VoiceCaption

  require Logger

  @tasks Hearth.Voice.CaptionTasks
  @topic "voice"

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(_opts), do: Task.Supervisor.child_spec(name: @tasks, max_children: limit())

  # The supervisor counts its children so peers starting at once can't pass the limit
  @spec caption(T.id(), T.id(), [ExRTP.Packet.t()]) :: :ok | :busy
  def caption(session_id, user_id, packets) when is_list(packets) do
    case Task.Supervisor.start_child(@tasks, fn -> run(session_id, user_id, packets) end) do
      {:ok, _task} -> :ok
      {:error, :max_children} -> :busy
    end
  end

  @spec run(T.id(), T.id(), [ExRTP.Packet.t()]) :: :ok
  def run(session_id, user_id, packets) do
    case TempFile.run(&transcribe(packets, &1)) do
      {:ok, ""} ->
        :ok

      {:ok, text} ->
        PubSub.broadcast(@topic, %VoiceCaption{
          session_id: session_id,
          user_id: user_id,
          text: text
        })

      {:error, reason} ->
        Logger.warning("Live caption failed: #{inspect(reason)}")
    end
  end

  defp transcribe(packets, path) do
    with :ok <- TrackFile.write_ogg(packets, path),
         {:ok, segments} <- AI.transcribe(path) do
      {:ok, segments |> Enum.map_join(" ", &String.trim(&1.text)) |> String.trim()}
    end
  end

  defp limit,
    do: :hearth |> Application.fetch_env!(Hearth.Voice) |> Keyword.fetch!(:caption_limit)
end
