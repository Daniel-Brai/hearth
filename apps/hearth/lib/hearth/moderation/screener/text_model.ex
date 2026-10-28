defmodule Hearth.Moderation.Screener.TextModel do
  # Qwen3Guard's categories were made for guarding AI chat so some don't fit a community and never hold anything

  alias Bumblebee.Text
  alias Hearth.Moderation.Verdict
  alias Nx.Serving

  @prompt_file Application.app_dir(:hearth, "priv/moderation/qwen3guard_prompt.json")
  @external_resource @prompt_file
  @prompt @prompt_file |> File.read!() |> Jason.decode!()
  @prefix Map.fetch!(@prompt, "prefix")
  @suffix Map.fetch!(@prompt, "suffix")

  @held [
    "Violent",
    "Non-violent Illegal Acts",
    "Sexual Content or Sexual Acts",
    "PII",
    "Suicide & Self-Harm",
    "Unethical Acts"
  ]

  # Unsafe is held and controversial only where the admin lowered the threshold
  @scores %{unsafe: 0.95, controversial: 0.4}

  # Two compiled lengths so short messages don't pay for long posts
  @lengths [512, 2_048]

  @spec load(String.t()) :: {Bumblebee.model_info(), Bumblebee.Tokenizer.t(), map()}
  def load(repo) do
    {:ok, model} = Bumblebee.load_model({:hf, repo}, type: :f32)
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, repo})
    {:ok, defaults} = Bumblebee.load_generation_config({:hf, repo})

    # Greedy decoding gives the same answer for the same text
    generation =
      Bumblebee.configure(defaults, max_new_tokens: 16, strategy: %{type: :greedy_search})

    {model, tokenizer, generation}
  end

  @spec serving(String.t(), pos_integer()) :: Serving.t()
  def serving(repo, batch_size) do
    {model, tokenizer, generation} = load(repo)

    Text.generation(model, tokenizer, generation,
      compile: [batch_size: batch_size, sequence_length: @lengths],
      defn_options: [compiler: EXLA]
    )
  end

  @spec predict(String.t()) :: {:ok, Verdict.t()} | {:error, :not_ready | :unreadable}
  def predict(text) do
    %{results: [%{text: answer}]} = Serving.batched_run(__MODULE__, prompt(text))
    parse(answer)
  catch
    # No serving is up yet on any node, which a retry outlives
    :exit, {:noproc, _call} -> {:error, :not_ready}
  end

  @spec prompt(String.t()) :: String.t()
  def prompt(text), do: @prefix <> "USER: " <> text <> @suffix

  @spec parse(String.t()) :: {:ok, Verdict.t()} | {:error, :unreadable}
  def parse(answer) do
    lines = String.split(answer, "\n", trim: true)

    with {:ok, safety} <- safety(lines) do
      {:ok, verdict(safety, categories(lines))}
    end
  end

  defp safety(["Safety: Safe" | _rest]), do: {:ok, :safe}
  defp safety(["Safety: Unsafe" | _rest]), do: {:ok, :unsafe}
  defp safety(["Safety: Controversial" | _rest]), do: {:ok, :controversial}
  defp safety(_lines), do: {:error, :unreadable}

  defp categories([_safety, "Categories: " <> list | _rest]) do
    list
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "None"))
  end

  defp categories(_lines), do: []

  defp verdict(:safe, _categories), do: Verdict.safe()

  defp verdict(safety, categories) do
    case Enum.filter(categories, &(&1 in @held)) do
      [] ->
        Verdict.safe()

      held ->
        %Verdict{
          verdict: safety,
          score: Map.fetch!(@scores, safety),
          categories: held,
          reason: "#{String.capitalize(Atom.to_string(safety))}: #{Enum.join(held, ", ")}"
        }
    end
  end
end
