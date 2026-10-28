defmodule Hearth.Voice.Captions do
  # Live captions run Whisper on the server, on stretches of speech each speaker's peer hands
  # over. They share the model with transcripts, so at most caption_limit stretches run at
  # once on a node and any more are dropped: a caption late or missing is better than a
  # backlog that slows the room

  alias Hearth.AI
  alias Hearth.Common.T
  alias Hearth.Media.TempFile
  alias Hearth.PubSub
  alias Hearth.Voice.TrackFile
  alias Hearth.Voice.VoiceCaption

  @tasks Hearth.Voice.CaptionTasks
  @topic "voice"

  @spec caption(T.id(), T.id(), [ExRTP.Packet.t()]) :: :ok | :busy
  def caption(session_id, user_id, packets) when is_list(packets) do
    case length(Task.Supervisor.children(@tasks)) < limit() do
      true ->
        {:ok, _task} =
          Task.Supervisor.start_child(@tasks, fn -> run(session_id, user_id, packets) end)

        :ok

      false ->
        :busy
    end
  end

  @spec run(T.id(), T.id(), [ExRTP.Packet.t()]) :: :ok
  def run(session_id, user_id, packets) do
    with {:ok, text} <- TempFile.run(&transcribe(packets, &1)),
         false <- text == "" do
      PubSub.broadcast(@topic, %VoiceCaption{session_id: session_id, user_id: user_id, text: text})
    end

    :ok
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
