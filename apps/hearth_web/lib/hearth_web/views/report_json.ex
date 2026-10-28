defmodule HearthWeb.ReportJSON do
  def create(%{}), do: %{queued: true}
end
