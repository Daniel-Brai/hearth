defmodule HearthWeb.Plugs.ApiDocsTest do
  use HearthWeb.ConnCase, async: false

  setup do
    previous = Application.get_env(:hearth_web, :api_docs)
    on_exit(fn -> Application.put_env(:hearth_web, :api_docs, previous) end)
  end

  describe "call/2" do
    test "returns 404 when the docs are off" do
      Application.put_env(:hearth_web, :api_docs, false)

      assert build_conn() |> get(~p"/docs") |> response(404)
      assert build_conn() |> get(~p"/redoc") |> response(404)
      assert build_conn() |> get(~p"/openapi.json") |> response(404)
    end

    test "serves the docs and the document" do
      assert build_conn() |> get(~p"/docs") |> html_response(200) =~ "swagger-ui"
      assert build_conn() |> get(~p"/redoc") |> html_response(200) =~ "redoc"

      assert %{"openapi" => "3.1.0"} =
               build_conn() |> get(~p"/openapi.json") |> json_response(200)
    end
  end
end
