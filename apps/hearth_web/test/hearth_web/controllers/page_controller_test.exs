defmodule HearthWeb.PageControllerTest do
  use HearthWeb.ConnCase, async: true

  describe "home" do
    test "renders the page" do
      conn = get(build_conn(), ~p"/")

      assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
    end
  end
end
