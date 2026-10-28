defmodule Hearth.Moderation.Command.ScreenContent do
  alias Hearth.Forum.Post
  alias Hearth.Media
  alias Hearth.Moderation.Command.HoldContent
  alias Hearth.Moderation.Item
  alias Hearth.Moderation.Screener
  alias Hearth.Moderation.Screening
  alias Hearth.Moderation.Subject
  alias Hearth.Moderation.Verdict
  alias Hearth.Repo

  @type plan :: %{text: boolean(), images: boolean(), queue: :automatic | :instance}

  # A screener that fails writes nothing so the job retries while the content stays up
  @spec execute(Subject.t(), plan()) ::
          {:ok, :passed} | {:ok, Item.t()} | {:error, term()}
  def execute(%Subject{} = subject, plan) do
    started = System.monotonic_time(:millisecond)

    with {:ok, verdict} <- screen(subject, plan) do
      duration = System.monotonic_time(:millisecond) - started
      Repo.transact(fn -> write(subject, plan.queue, verdict, duration) end)
    end
  end

  defp write(subject, queue, verdict, duration) do
    held? = verdict.score >= Screener.threshold()

    with {:ok, _screening} <- record(subject, verdict, held?, duration) do
      hold(subject, queue, verdict, held?)
    end
  end

  defp screen(subject, plan) do
    with {:ok, text} <- screen_text(subject, plan),
         {:ok, images} <- screen_images(subject, plan) do
      {:ok, Enum.reduce(images, text, &Verdict.worst/2)}
    end
  end

  defp screen_text(subject, %{text: true}) do
    case text(subject.content) do
      "" -> {:ok, Verdict.safe()}
      text -> Screener.screen_text(text)
    end
  end

  defp screen_text(_subject, _plan), do: {:ok, Verdict.safe()}

  defp screen_images(subject, %{images: true}) do
    with {:ok, images} <- Media.read_images(subject.type, subject.content.id) do
      Enum.reduce_while(images, {:ok, []}, &screen_image/2)
    end
  end

  defp screen_images(_subject, _plan), do: {:ok, []}

  defp screen_image(bytes, {:ok, verdicts}) do
    case Screener.screen_image(bytes) do
      {:ok, verdict} -> {:cont, {:ok, [verdict | verdicts]}}
      error -> {:halt, error}
    end
  end

  defp text(%Post{title: title, body: body}), do: String.trim("#{title}\n\n#{body}")
  defp text(%{body: body}), do: String.trim(body || "")

  defp record(subject, verdict, held?, duration) do
    Screening.insert(
      %Screening{
        community_id: subject.community_id,
        subject_type: subject.type,
        subject_id: subject.content.id,
        screener: Screener.name(),
        verdict: verdict.verdict,
        score: verdict.score,
        categories: verdict.categories,
        held: held?,
        duration_ms: duration
      },
      %{}
    )
  end

  defp hold(_subject, _queue, _verdict, false), do: {:ok, :passed}

  defp hold(subject, queue, verdict, true) do
    HoldContent.execute(subject, queue, %{reason: verdict.reason, score: verdict.score})
  end
end
