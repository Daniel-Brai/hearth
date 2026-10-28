defmodule HearthWeb.ErrorJSONTest do
  use HearthWeb.ConnCase, async: true

  alias Ecto.Changeset
  alias HearthWeb.ErrorJSON

  describe "render/2" do
    test "names the status" do
      assert ErrorJSON.render("404.json", %{}) == %{message: "Not Found"}
    end

    test "adds a code" do
      assert ErrorJSON.render("400.json", %{code: :expired_code}) ==
               %{message: "Bad Request", code: :expired_code}
    end

    test "lists a changeset's errors by field path" do
      changeset =
        {%{}, %{name: :string, parts: {:array, :map}}}
        |> Changeset.cast(%{}, [:name])
        |> Changeset.validate_required([:name])
        |> Changeset.add_error(:name, "is at most %{count} long", count: 3)

      assert %{message: "Unprocessable Content", errors: %{"name" => messages}} =
               ErrorJSON.render("422.json", %{changeset: changeset})

      assert "is at most 3 long" in messages
    end
  end
end
