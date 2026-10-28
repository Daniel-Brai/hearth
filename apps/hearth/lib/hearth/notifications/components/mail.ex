defmodule Hearth.Notifications.MailComponent do
  use Phoenix.Component

  embed_templates("templates/*")

  attr(:title, :string, required: true)
  attr(:preview, :string, default: nil)
  attr(:brand, :string, required: true)
  attr(:icon, :string, required: true)
  attr(:url, :string, required: true)
  attr(:host, :boolean, default: true, doc: "Names the instance's address under the card.")
  slot(:inner_block, required: true)
  slot(:footer)
  def layout(assigns)

  slot(:inner_block, required: true)
  def heading(assigns)

  attr(:line, :any, required: true, doc: "A string, or a `MailMessage.link_line/4` line.")
  def line(assigns)

  attr(:url, :string, required: true)
  attr(:color, :atom, default: :primary, values: ~w[primary success error]a)
  slot(:inner_block, required: true)
  def button(assigns)

  slot(:inner_block, required: true)
  def code(assigns)

  attr(:heading, :string, required: true)
  attr(:url, :string, required: true)
  attr(:items, :list, required: true)
  attr(:more, :any, default: nil)
  def section(assigns)

  # Full addresses appear only here, for clients that won't open the button
  attr(:url, :string, required: true)
  def fallback(assigns)

  @doc false
  def button_background(:error), do: "#b42318"
  def button_background(:success), do: "#1f7a4d"
  def button_background(:primary), do: "#1d2433"
end
