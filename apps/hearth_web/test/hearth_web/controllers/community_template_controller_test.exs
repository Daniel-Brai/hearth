defmodule HearthWeb.CommunityTemplateControllerTest do
  use HearthWeb.ConnCase, async: true

  describe "index" do
    test "lists each template with what it sets up", %{conn: conn} do
      conn = get(conn, ~p"/api/community-templates")
      templates = valid_response(conn, 200)

      assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]

      assert [
               %{"id" => "club"},
               %{"id" => "local"},
               %{"id" => "creator"},
               %{"id" => "class"},
               %{"id" => "support"},
               %{"id" => "oss"} = oss,
               %{"id" => "blank"} = blank
             ] = templates

      assert "bug" in oss["kinds"]
      assert %{"title" => "Office hours", "repeat" => "weekly"} = oss["event"]
      assert %{"event" => nil, "voice" => nil} = blank
    end
  end
end
