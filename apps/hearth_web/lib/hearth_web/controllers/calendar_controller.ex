defmodule HearthWeb.CalendarController do
  use HearthWeb, :controller

  alias Hearth.Communities
  alias HearthWeb.Calendar

  # The body is iCalendar text with its own content type, so a browser never runs it as a page
  # sobelow_skip ["XSS.SendResp"]
  def show(conn, %{"file" => file}) do
    with [slug, "ics"] <- String.split(file, "."),
         {:ok, community} <- Communities.get_community(slug: slug),
         true <- Communities.readable?(community, nil) do
      conn
      |> put_resp_content_type("text/calendar")
      |> put_resp_header("cache-control", "public, max-age=900")
      |> send_resp(:ok, Calendar.community(community))
    else
      _hidden -> send_resp(conn, :not_found, "")
    end
  end
end
