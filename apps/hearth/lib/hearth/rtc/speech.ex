defmodule Hearth.RTC.Speech do
  # Whether someone is speaking and the stretch of speech kept for captions
  # Each function takes the time and returns what the peer should do

  alias ExRTP.Packet

  # A packet at or under this level in -dBov counts as speech
  # and speech stops counting this long after the last one
  @loud_level 50
  @speaking_ms 400

  # With captions on a stretch of speech goes for captioning when the speaker pauses or hits the longest
  # A stretch shorter than the least is a cough or a click
  @phrase_max_ms 6_000
  @phrase_min_ms 600

  defstruct speaking?: false, loud_at: nil, phrase: nil

  @type phrase :: %{started_at: integer(), packets: [Packet.t()]}

  @type t :: %__MODULE__{
          speaking?: boolean(),
          loud_at: nil | integer(),
          phrase: nil | phrase()
        }

  @type event :: {:speaking, boolean()} | {:phrase, [Packet.t()]} | {:check_in, pos_integer()}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  # A packet with no level counts as loud since the browser didn't say
  @spec heard(t(), nil | non_neg_integer(), integer()) :: {t(), [event()]}
  def heard(%__MODULE__{} = speech, level, _now) when is_integer(level) and level > @loud_level,
    do: {speech, []}

  def heard(%__MODULE__{speaking?: true} = speech, _level, now),
    do: {%{speech | loud_at: now}, []}

  def heard(%__MODULE__{} = speech, _level, now) do
    {%{speech | loud_at: now, speaking?: true}, [{:speaking, true}, {:check_in, @speaking_ms}]}
  end

  @spec check(t(), integer()) :: {t(), [event()]}
  def check(%__MODULE__{speaking?: false} = speech, _now), do: {speech, []}

  def check(%__MODULE__{} = speech, now) do
    quiet_for = now - (speech.loud_at || 0)

    case quiet_for >= @speaking_ms do
      true ->
        {speech, events} = hand_over(%{speech | speaking?: false}, now)
        {speech, [{:speaking, false} | events]}

      false ->
        {speech, [{:check_in, @speaking_ms - quiet_for}]}
    end
  end

  @spec keep(t(), boolean(), :audio | :video, Packet.t(), integer()) :: {t(), [event()]}
  def keep(%__MODULE__{speaking?: true} = speech, true, :audio, packet, now) do
    phrase = speech.phrase || %{started_at: now, packets: []}
    speech = %{speech | phrase: %{phrase | packets: [packet | phrase.packets]}}

    case now - phrase.started_at >= @phrase_max_ms do
      true -> hand_over(speech, now)
      false -> {speech, []}
    end
  end

  def keep(%__MODULE__{phrase: %{}} = speech, false, _kind, _packet, _now),
    do: {%{speech | phrase: nil}, []}

  def keep(%__MODULE__{} = speech, _caption?, _kind, _packet, _now), do: {speech, []}

  defp hand_over(%{phrase: nil} = speech, _now), do: {speech, []}

  defp hand_over(%{phrase: phrase} = speech, now) do
    case now - phrase.started_at >= @phrase_min_ms do
      true -> {%{speech | phrase: nil}, [{:phrase, Enum.reverse(phrase.packets)}]}
      false -> {%{speech | phrase: nil}, []}
    end
  end
end
