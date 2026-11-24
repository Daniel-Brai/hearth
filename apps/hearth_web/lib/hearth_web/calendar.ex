defmodule HearthWeb.Calendar do
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.Notifications

  @rules %{
    daily: "FREQ=DAILY",
    weekly: "FREQ=WEEKLY",
    biweekly: "FREQ=WEEKLY;INTERVAL=2",
    monthly: "FREQ=MONTHLY"
  }

  # A line break in a title could start a new property in a subscriber's calendar
  @controls 0..31 |> Enum.reject(&(&1 == ?\t)) |> Enum.map(&<<&1>>)

  # Lines longer than this many bytes continue on the next line, as iCalendar asks
  @line_bytes 75

  @spec community(map()) :: iodata()
  def community(%{} = community) do
    rooms =
      community |> Communities.list_rooms(fields: [:id, :name]) |> Map.new(&{&1.id, &1.name})

    events = Events.list_calendar_events(community.id)

    [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Hearth//Events//EN",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH",
      "X-WR-CALNAME:" <> escape(community.name),
      "REFRESH-INTERVAL;VALUE=DURATION:PT1H",
      "X-PUBLISHED-TTL:PT1H"
    ]
    |> Enum.concat(Enum.flat_map(events, &event(&1, community, rooms)))
    |> Enum.concat(["END:VCALENDAR"])
    |> Enum.map(&[fold(&1), "\r\n"])
  end

  defp event(%{} = event, community, rooms) do
    Enum.reject(
      [
        "BEGIN:VEVENT",
        "UID:#{event.id}@hearth",
        "DTSTAMP:" <> utc(event.updated_at),
        starts(event),
        "DURATION:PT#{event.duration_min}M",
        rule(event.repeat),
        "SUMMARY:" <> escape(event.title),
        description(event.description),
        "LOCATION:" <> escape(location(event, community, rooms)),
        "URL:" <> event_url(event, community),
        status(event.cancelled_at),
        "END:VEVENT"
      ],
      &is_nil/1
    )
  end

  defp event_url(event, community),
    do: Notifications.url("/c/#{community.slug}/e/" <> Common.id_slug(event.id, event.title))

  # Repeats keep the wall clock time of their own zone across daylight saving
  defp starts(%{repeat: :none, starts_at: starts_at}), do: "DTSTART:" <> utc(starts_at)

  defp starts(%{} = event) do
    local =
      event.starts_at
      |> DateTime.shift_zone!(event.timezone)
      |> DateTime.to_naive()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601(:basic)

    "DTSTART;TZID=#{event.timezone}:" <> local
  end

  defp rule(:none), do: nil
  defp rule(repeat), do: "RRULE:" <> Map.fetch!(@rules, repeat)

  defp description(nil), do: nil
  defp description(markdown), do: "DESCRIPTION:" <> escape(Common.plain_text(markdown))

  defp location(%{place: :link, url: url}, _community, _rooms), do: url

  defp location(%{room_id: room_id}, community, rooms) do
    case rooms[room_id] do
      nil -> community.name
      name -> "#{community.name} ##{name}"
    end
  end

  defp status(nil), do: nil
  defp status(_cancelled_at), do: "STATUS:CANCELLED"

  defp utc(%DateTime{} = at) do
    at
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
  end

  defp escape(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace(";", "\\;")
    |> String.replace(",", "\\,")
    |> String.replace(["\r\n", "\r", "\n"], "\\n")
    |> String.replace(@controls, "")
  end

  # Continuation lines start with a space, which counts toward their length
  defp fold(line, bytes \\ @line_bytes)
  defp fold(line, bytes) when byte_size(line) <= bytes, do: line

  defp fold(line, bytes) do
    {first, rest} = split_at(line, bytes)
    [first, "\r\n ", fold(rest, @line_bytes - 1)]
  end

  # Never cuts a character in half
  defp split_at(text, bytes) do
    cut =
      text
      |> String.graphemes()
      |> Enum.reduce_while(0, fn grapheme, size ->
        case size + byte_size(grapheme) > bytes do
          true -> {:halt, size}
          false -> {:cont, size + byte_size(grapheme)}
        end
      end)

    {binary_part(text, 0, cut), binary_part(text, cut, byte_size(text) - cut)}
  end
end
