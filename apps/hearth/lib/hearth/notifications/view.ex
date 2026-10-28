defmodule Hearth.Notifications.View do
  use Phoenix.Component

  alias Hearth.Notifications.MailComponent, as: Mail

  embed_templates("templates/*")

  attr(:brand, :string, required: true)
  attr(:url, :string, required: true)
  attr(:subject, :string, required: true)
  attr(:preview, :string, default: nil)
  attr(:greeting, :string, default: nil)
  attr(:level, :atom, default: :info)
  attr(:action_text, :string, default: nil)
  attr(:action_url, :string, default: nil)
  attr(:code, :string, default: nil)
  attr(:intro_lines, :list, default: [])
  attr(:sections, :list, default: [])
  attr(:outro_lines, :list, default: [])
  def email(assigns)

  @doc false
  def button_color(level) when level in [:error, :success], do: level
  def button_color(_level), do: :primary
end
