defmodule Hearth.Moderation.Screener do
  alias Hearth.Common
  alias Hearth.Moderation.Verdict
  alias Hearth.ScreeningPolicy

  @type opts :: [guidelines: nil | String.t()]

  @callback screen_text(String.t(), opts()) :: {:ok, Verdict.t()} | {:error, term()}
  @callback screen_image(binary(), opts()) :: {:ok, Verdict.t()} | {:error, term()}

  @screeners %{local: __MODULE__.Local, hosted: __MODULE__.Hosted}

  @spec impl() :: nil | module()
  def impl do
    case ScreeningPolicy.screener() do
      :off -> nil
      name when is_map_key(@screeners, name) -> Map.fetch!(@screeners, name)
      module when is_atom(module) -> module
    end
  end

  @spec enabled?() :: boolean()
  def enabled?, do: impl() != nil

  @spec image_floor?() :: boolean()
  defdelegate image_floor?, to: ScreeningPolicy

  @spec threshold() :: float()
  def threshold, do: config(:threshold)

  @spec name() :: String.t()
  def name do
    case ScreeningPolicy.screener() do
      name when is_map_key(@screeners, name) -> Atom.to_string(name)
      module -> inspect(module)
    end
  end

  @spec screen_text(String.t(), opts()) :: {:ok, Verdict.t()} | {:error, term()}
  def screen_text(text, opts \\ []) when is_binary(text) do
    text = String.slice(text, 0, config(:max_text))
    Common.span("screening.text", %{screener: name()}, fn -> impl().screen_text(text, opts) end)
  end

  @spec screen_image(binary(), opts()) :: {:ok, Verdict.t()} | {:error, term()}
  def screen_image(image, opts \\ []) when is_binary(image) do
    Common.span("screening.image", %{screener: name(), bytes: byte_size(image)}, fn ->
      impl().screen_image(image, opts)
    end)
  end

  defp config(key), do: :hearth |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(key)
end
