defmodule Hearth.AI.Transcriber do
  @type segment :: %{start_ms: non_neg_integer(), end_ms: non_neg_integer(), text: String.t()}
  @type error :: :not_ready | :unreadable

  @callback transcribe(Path.t()) :: {:ok, [segment()]} | {:error, error()}
  @callback model() :: String.t()

  @spec impl() :: module()
  def impl, do: :hearth |> Application.fetch_env!(Hearth.AI) |> Keyword.fetch!(:transcriber)
end
