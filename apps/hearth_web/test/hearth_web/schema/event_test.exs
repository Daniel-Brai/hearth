defmodule HearthWeb.Schema.EventTest do
  use ExUnit.Case, async: true

  alias HearthWeb.ConnCase

  describe "all/0" do
    test "describes every field each event sends" do
      assert ConnCase.events_with_undescribed_fields() == []
    end

    test "names schemas after events" do
      assert ConnCase.events_with_other_names() == []
    end
  end
end
