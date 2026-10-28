defmodule Hearth.Moderation.Screener.Stub do
  # Markers in the text decide the answer as [unsafe] [controversial] or [down]

  @behaviour Hearth.Moderation.Screener

  alias Hearth.Moderation.Verdict

  @impl Hearth.Moderation.Screener
  def screen_text(text, _opts) do
    cond do
      text =~ "[down]" -> {:error, :not_ready}
      text =~ "[unsafe]" -> {:ok, unsafe("Unsafe: Violent")}
      text =~ "[controversial]" -> {:ok, controversial()}
      true -> {:ok, Verdict.safe()}
    end
  end

  @impl Hearth.Moderation.Screener
  def screen_image("unsafe" <> _rest, _opts), do: {:ok, unsafe("Unsafe: image")}
  def screen_image(_bytes, _opts), do: {:ok, Verdict.safe()}

  defp unsafe(reason) do
    %Verdict{verdict: :unsafe, score: 0.95, categories: ["Violent"], reason: reason}
  end

  defp controversial do
    %Verdict{verdict: :controversial, score: 0.4, categories: ["Unethical Acts"], reason: "Maybe"}
  end
end
