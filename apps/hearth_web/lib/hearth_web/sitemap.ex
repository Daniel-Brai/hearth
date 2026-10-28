defmodule HearthWeb.Sitemap do
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.Forum
  alias Hearth.Instance
  alias Hearth.Notifications
  alias Plug.HTML

  @max_urls 50_000

  # Signed in areas and screens nobody searches for
  @disallow ~w[
    /api/ /signin /join/ /new /people /dm/ /settings /requests /invites /events
    /c/*/chat/ /c/*/voice/ /c/*/sessions/ /c/*/new /c/*/invite /c/*/moderation
    /c/*/roles /c/*/log /*?
  ]

  @spec robots() :: String.t()
  def robots do
    case Instance.indexing?() do
      true ->
        Enum.join(
          ["User-agent: *", "Allow: /c/", "Allow: /u/"] ++
            Enum.map(@disallow, &("Disallow: " <> &1)) ++
            ["", "Sitemap: " <> Notifications.url("/sitemap.xml")],
          "\n"
        ) <> "\n"

      false ->
        "User-agent: *\nDisallow: /\n"
    end
  end

  @spec index() :: iodata()
  def index do
    communities =
      case Instance.indexing?() do
        true -> Communities.list_indexed()
        false -> []
      end

    ids = Enum.map(communities, & &1.id)
    posts = Forum.sitemap_stats(ids)
    events = Events.count_sitemap_events(ids)

    entries =
      for community <- communities,
          {count, last} = Map.get(posts, community.id, {0, nil}),
          page <- 1..pages(count, Map.get(events, community.id, 0)) do
        [
          "<sitemap><loc>",
          escape(Notifications.url("/sitemaps/" <> file(community.slug, page))),
          "</loc>",
          lastmod(last || community.updated_at),
          "</sitemap>"
        ]
      end

    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">),
      entries,
      "</sitemapindex>\n"
    ]
  end

  @spec community(String.t()) :: {:ok, iodata()} | {:error, :not_found}
  def community(file) do
    with true <- Instance.indexing?(),
         {:ok, slug, page} <- parse(file),
         %{} = community <- Enum.find(Communities.list_indexed(), &(&1.slug == slug)),
         {:ok, urls} <- urls(community, page) do
      {:ok,
       [
         ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
         ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">),
         Enum.map(urls, &url/1),
         "</urlset>\n"
       ]}
    else
      _missing -> {:error, :not_found}
    end
  end

  defp urls(%{slug: slug} = community, 1) do
    events = Events.sitemap_events(community.id)
    first = [{"/c/" <> slug, community.updated_at}, {"/c/#{slug}/events", community.updated_at}]
    room = max(@max_urls - length(first) - length(events), 0)

    {:ok,
     first ++
       Enum.map(events, &{"/c/#{slug}/e/" <> Common.id_slug(&1.id, &1.title), &1.updated_at}) ++
       posts(community, 0, room)}
  end

  defp urls(community, page) when page > 1 do
    on_first = max(@max_urls - 2 - length(Events.sitemap_events(community.id)), 0)

    case posts(community, on_first + (page - 2) * @max_urls, @max_urls) do
      [] -> {:error, :not_found}
      urls -> {:ok, urls}
    end
  end

  defp posts(%{slug: slug, id: id}, offset, limit) do
    id
    |> Forum.sitemap_posts(offset, limit)
    |> Enum.map(&{"/c/#{slug}/p/" <> Common.id_slug(&1.id, &1.title), &1.updated_at})
  end

  defp pages(posts, events) do
    extra = posts + events + 2 - @max_urls

    case extra > 0 do
      true -> 1 + div(extra + @max_urls - 1, @max_urls)
      false -> 1
    end
  end

  defp file(slug, 1), do: slug <> ".xml"
  defp file(slug, page), do: "#{slug}.#{page}.xml"

  defp parse(file) do
    case String.split(file, ".") do
      [slug, "xml"] -> {:ok, slug, 1}
      [slug, page, "xml"] -> with {n, ""} when n > 1 <- Integer.parse(page), do: {:ok, slug, n}
      _other -> :error
    end
  end

  defp url({path, updated_at}),
    do: ["<url><loc>", escape(Notifications.url(path)), "</loc>", lastmod(updated_at), "</url>"]

  defp lastmod(nil), do: []

  defp lastmod(%DateTime{} = at),
    do: ["<lastmod>", at |> DateTime.truncate(:second) |> DateTime.to_iso8601(), "</lastmod>"]

  defp escape(text), do: HTML.html_escape_to_iodata(text)
end
