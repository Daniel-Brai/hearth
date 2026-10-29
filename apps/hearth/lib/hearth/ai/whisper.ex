defmodule Hearth.AI.Whisper do
  # Until the model is up a call answers {:error, :not_ready} and the job waits
  # Each stretch of speech is read on its own and becomes one segment with its own times,
  # since Bumblebee's timestamp step doesn't compile on Nx 1.0 and a speaker's track is mostly silence

  @behaviour Hearth.AI.Transcriber

  use Supervisor

  alias Bumblebee.Audio
  alias Hearth.Common
  alias Hearth.Media.Video
  alias Nx.Serving

  require Logger

  @rate 16_000
  @bytes_per_ms div(@rate * 4, 1_000)
  # Whisper reads 30 second windows, so longer stretches are cut a little under that
  @longest_ms 28_000
  @shortest_ms 300

  @impl Hearth.AI.Transcriber
  def model, do: config(:model)

  @impl Hearth.AI.Transcriber
  # path is a temp file the caller made, never a name from a request
  # sobelow_skip ["Traversal.FileModule"]
  def transcribe(path) do
    Common.span("whisper.transcribe", %{model: model()}, fn -> run(path) end)
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp run(path) do
    pcm = path <> ".pcm"

    with :ok <- decode(path, pcm),
         {:ok, silences} <- Video.silences(path) do
      %{size: size} = File.stat!(pcm)

      # The serving batches calls that arrive together, so stretches go in side by side
      silences
      |> speech(div(size, @bytes_per_ms))
      |> Task.async_stream(&read_stretch(pcm, &1),
        max_concurrency: config(:batch_size),
        timeout: :infinity
      )
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, {:ok, segment}}, {:ok, segments} -> {:cont, {:ok, [segment | segments]}}
        {:ok, error}, _segments -> {:halt, error}
      end)
      |> ordered()
    else
      {:error, :not_converted} -> {:error, :unreadable}
    end
  after
    File.rm(path <> ".pcm")
  end

  @spec speech([{non_neg_integer(), nil | non_neg_integer()}], non_neg_integer()) ::
          [{non_neg_integer(), non_neg_integer()}]
  def speech(silences, duration_ms) do
    {stretches, from} =
      Enum.reduce(silences, {[], 0}, fn {start_ms, end_ms}, {stretches, from} ->
        {[{from, start_ms} | stretches], end_ms || duration_ms}
      end)

    [{from, duration_ms} | stretches]
    |> Enum.reverse()
    |> Enum.filter(fn {from, to} -> to - from >= @shortest_ms end)
    |> Enum.flat_map(&cut/1)
  end

  defp cut({from, to}) when to - from <= @longest_ms, do: [{from, to}]
  defp cut({from, to}), do: [{from, from + @longest_ms} | cut({from + @longest_ms, to})]

  defp read_stretch(pcm, {from, to}) do
    {:ok, file} = :file.open(pcm, ~w[read binary raw]a)

    {:ok, data} =
      try do
        :file.pread(file, from * @bytes_per_ms, (to - from) * @bytes_per_ms)
      after
        :file.close(file)
      end

    %{chunks: chunks} = Serving.batched_run(__MODULE__, Nx.from_binary(data, :f32))
    text = chunks |> Enum.map_join(" ", &String.trim(&1.text)) |> String.trim()

    {:ok, %{start_ms: from, end_ms: to, text: text}}
  catch
    # No serving is up yet on any node, which a retry outlives
    :exit, {:noproc, _call} -> {:error, :not_ready}
  end

  defp ordered({:ok, segments}),
    do: {:ok, segments |> Enum.reject(&(&1.text == "")) |> Enum.reverse()}

  defp ordered(error), do: error

  @spec serving(String.t(), pos_integer()) :: Serving.t()
  def serving(repo, batch_size) do
    {:ok, model} = Bumblebee.load_model({:hf, repo}, type: :f32)
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, repo})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, repo})
    {:ok, generation} = Bumblebee.load_generation_config({:hf, repo})

    Audio.speech_to_text_whisper(model, featurizer, tokenizer, generation,
      compile: [batch_size: batch_size],
      defn_options: [compiler: EXLA]
    )
  end

  # Nx.Serving takes the serving's name plus Supervisor for itself
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__.Loader)

  @impl Supervisor
  def init(_opts) do
    children = [
      {DynamicSupervisor, name: __MODULE__.Servings, strategy: :one_for_one},
      Supervisor.child_spec({Task, &start_serving/0}, restart: :transient)
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  # Loads in the background since the first start downloads the model
  defp start_serving do
    repo = config(:model)
    {time, serving} = :timer.tc(fn -> serving(repo, config(:batch_size)) end)

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        __MODULE__.Servings,
        {Nx.Serving,
         serving: serving,
         name: __MODULE__,
         batch_size: config(:batch_size),
         batch_timeout: config(:batch_timeout)}
      )

    Logger.info("Transcription model #{repo} is up after #{div(time, 1_000)} ms")
  end

  defp decode(input, output) do
    Video.run_ffmpeg([
      "-v",
      "error",
      "-y",
      "-i",
      input,
      "-ac",
      "1",
      "-ar",
      "16000",
      "-f",
      "f32le",
      output
    ])
  end

  defp config(key), do: :hearth |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(key)
end
