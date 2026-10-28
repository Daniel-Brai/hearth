defmodule Hearth.Moderation.Screener.Hosted.Assessment do
  # A model can still answer outside the schema so anything that doesn't match raises and the job retries

  alias Hearth.Moderation.Verdict

  @verdicts %{"safe" => :safe, "controversial" => :controversial, "unsafe" => :unsafe}

  @spec schema() :: map()
  def schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["verdict", "score", "categories", "reason"],
      "properties" => %{
        "verdict" => %{"type" => "string", "enum" => Map.keys(@verdicts)},
        "score" => %{"type" => "number", "minimum" => 0, "maximum" => 1},
        "categories" => %{"type" => "array", "items" => %{"type" => "string"}},
        "reason" => %{"type" => ["string", "null"]}
      }
    }
  end

  @spec from!(map()) :: no_return() | Verdict.t()
  def from!(%{} = data) do
    %{"verdict" => verdict, "score" => score, "categories" => categories, "reason" => reason} =
      data

    %Verdict{
      verdict: Map.fetch!(@verdicts, verdict),
      score: score(score),
      categories: categories(categories),
      reason: reason(reason)
    }
  end

  defp score(score) when is_number(score) and score >= 0 and score <= 1, do: score / 1
  defp score(score), do: raise(ArgumentError, "score out of range: #{inspect(score)}")

  defp categories(list) when is_list(list) do
    if Enum.all?(list, &is_binary/1), do: list, else: raise(ArgumentError, "categories")
  end

  defp categories(other), do: raise(ArgumentError, "categories: #{inspect(other)}")

  defp reason(nil), do: nil
  defp reason(reason) when is_binary(reason), do: String.slice(reason, 0, 500)
  defp reason(other), do: raise(ArgumentError, "reason: #{inspect(other)}")
end
