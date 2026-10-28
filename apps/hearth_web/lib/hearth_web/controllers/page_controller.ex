defmodule HearthWeb.PageController do
  use HearthWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
