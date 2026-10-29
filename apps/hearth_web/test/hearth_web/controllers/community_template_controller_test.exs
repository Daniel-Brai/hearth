defmodule HearthWeb.CommunityTemplateControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.TestUtils

  describe "index" do
    test "lists each template with what it sets up", %{conn: conn} do
      templates = conn |> get(~p"/api/community-templates") |> valid_response(200)

      [club | _rest] = templates

      assert TestUtils.pluck(templates, "id") == ~w[club local creator class support oss blank]
      assert "question" in club["kinds"]
    end
  end
end
