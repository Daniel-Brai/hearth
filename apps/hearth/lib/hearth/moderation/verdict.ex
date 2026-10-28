defmodule Hearth.Moderation.Verdict do
  @fields ~w[verdict score categories reason]a
  @enforce_keys @fields
  defstruct @fields

  @type verdict :: :safe | :controversial | :unsafe
  @type t :: %__MODULE__{
          verdict: verdict(),
          score: float(),
          categories: [String.t()],
          reason: nil | String.t()
        }

  @verdicts ~w[safe controversial unsafe]a

  @spec verdicts() :: [verdict()]
  def verdicts, do: @verdicts

  @spec safe() :: t()
  def safe, do: %__MODULE__{verdict: :safe, score: 0.0, categories: [], reason: nil}

  @spec worst(t(), t()) :: t()
  def worst(%__MODULE__{score: a} = first, %__MODULE__{score: b}) when a >= b, do: first
  def worst(%__MODULE__{}, %__MODULE__{} = second), do: second
end
