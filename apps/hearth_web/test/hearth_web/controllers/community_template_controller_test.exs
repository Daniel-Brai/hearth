defmodule HearthWeb.CommunityTemplateControllerTest do
  use HearthWeb.ConnCase, async: true

  describe "index" do
    test "lists each template with what it sets up", %{conn: conn} do
      conn = get(conn, ~p"/api/community-templates")
      templates = valid_response(conn, 200)

      assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]

      assert Enum.map(templates, & &1["id"]) == ~w[club local creator class support oss blank]

      assert [_club, _local, _creator, _class, _support, oss, blank] = templates
      assert "bug" in oss["kinds"]
      assert %{"title" => "Office hours", "repeat" => "weekly"} = oss["event"]
      assert %{"event" => nil, "voice" => nil} = blank
    end
  end
end
