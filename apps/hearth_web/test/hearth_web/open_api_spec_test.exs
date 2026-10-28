defmodule HearthWeb.OpenAPISpecTest do
  use ExUnit.Case, async: true

  @path Path.expand("../../priv/openapi.json", __DIR__)

  describe "spec/0" do
    test "matches generated document" do
      written = @path |> File.read!() |> Jason.decode!()
      current = HearthWeb.OpenAPISpec |> Oaskit.to_json!(%{pretty: false}) |> Jason.decode!()

      assert written == current, "priv/openapi.json is out of date; run `mix api.spec`"
    end
  end
end
