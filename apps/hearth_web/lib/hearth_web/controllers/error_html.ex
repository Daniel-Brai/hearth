defmodule HearthWeb.ErrorHTML do
  use HearthWeb, :html

  alias Phoenix.Controller

  def render(template, _assigns) do
    Controller.status_message_from_template(template)
  end
end
