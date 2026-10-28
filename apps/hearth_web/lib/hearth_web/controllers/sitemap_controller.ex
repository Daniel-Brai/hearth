defmodule HearthWeb.SitemapController do
  use HearthWeb, :controller

  alias HearthWeb.Sitemap

  def robots(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_cached(Sitemap.robots())
  end

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    |> send_cached(Sitemap.index())
  end

  def show(conn, %{"file" => file}) do
    case Sitemap.community(file) do
      {:ok, xml} ->
        conn
        |> put_resp_content_type("application/xml")
        |> send_cached(xml)

      {:error, :not_found} ->
        send_resp(conn, :not_found, "")
    end
  end

  # Every caller sets a plain text or XML content type first, and the XML
  # escapes what it carries, so a browser never runs the body as a page.
  # sobelow_skip ["XSS.SendResp"]
  defp send_cached(conn, body) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(:ok, body)
  end
end
