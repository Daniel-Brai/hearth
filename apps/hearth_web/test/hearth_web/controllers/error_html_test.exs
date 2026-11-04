defmodule HearthWeb.ErrorHTMLTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  alias HearthWeb.ErrorHTML

  test "renders 404.html" do
    assert render_to_string(ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
