defmodule Hearth.Moderation.Screener.ImageModel do
  alias Bumblebee.Vision
  alias Hearth.Moderation.Verdict
  alias Nx.Serving

  # The classifier looks at 224 pixel squares so a bigger picture only
  # costs time to decode
  @side 256

  @spec load(String.t()) :: {Bumblebee.model_info(), Bumblebee.Featurizer.t()}
  def load(repo) do
    {:ok, model} = Bumblebee.load_model({:hf, repo})
    # The repo names a processor class Bumblebee can't infer so it's named here
    {:ok, featurizer} =
      Bumblebee.load_featurizer({:hf, repo}, module: Bumblebee.Vision.VitFeaturizer)

    {model, featurizer}
  end

  @spec serving(String.t(), pos_integer()) :: Serving.t()
  def serving(repo, batch_size) do
    {model, featurizer} = load(repo)

    Vision.image_classification(model, featurizer,
      top_k: 2,
      compile: [batch_size: batch_size],
      defn_options: [compiler: EXLA]
    )
  end

  @spec predict(binary()) :: {:ok, Verdict.t()} | {:error, :not_ready | :unreadable}
  def predict(bytes) do
    with {:ok, pixels} <- pixels(bytes) do
      %{predictions: predictions} = Serving.batched_run(__MODULE__, pixels)
      {:ok, verdict(predictions)}
    end
  catch
    :exit, {:noproc, _call} -> {:error, :not_ready}
  end

  @spec verdict([%{label: String.t(), score: float()}]) :: Verdict.t()
  def verdict(predictions) do
    score =
      Enum.find_value(predictions, 0.0, fn
        %{label: "nsfw", score: score} -> score
        _other -> nil
      end)

    %Verdict{
      verdict: if(score >= 0.5, do: :unsafe, else: :safe),
      score: score,
      categories: if(score >= 0.5, do: ["Sexual Content or Sexual Acts"], else: []),
      reason: if(score >= 0.5, do: "Unsafe: Sexual Content or Sexual Acts in an image")
    }
  end

  defp pixels(bytes) do
    with {:ok, image} <- Image.from_binary(bytes),
         {:ok, small} <- Image.thumbnail(image, @side),
         {:ok, flat} <- Image.flatten(small),
         {:ok, srgb} <- Image.to_colorspace(flat, :srgb),
         {:ok, tensor} <- Image.to_nx(srgb, shape: :hwc) do
      {:ok, tensor}
    else
      _error -> {:error, :unreadable}
    end
  end
end
