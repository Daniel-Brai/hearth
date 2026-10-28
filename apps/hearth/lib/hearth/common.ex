defmodule Hearth.Common do
  use Boundary, exports: [Id, Link, T]

  alias Hearth.Common.Id
  alias Hearth.Common.MailDomain
  alias Hearth.Common.Markdown
  alias Hearth.Common.Slug
  alias Hearth.Common.String
  alias Hearth.Common.Text
  alias Hearth.Common.Trace
  alias Hearth.Common.Transform

  defdelegate new_id, to: Id, as: :new
  defdelegate valid_id?(value), to: Id, as: :valid?

  defdelegate slugify(text), to: Slug
  defdelegate id_slug(id, title), to: Slug
  defdelegate id_from_segment(segment), to: Slug

  defdelegate remove_nil_fields(value), to: Transform
  defdelegate atomize_string_keys(map), to: Transform
  defdelegate to_atom(value), to: String

  defdelegate normalize(value), to: Text
  defdelegate valid_username?(value), to: Text

  defdelegate mail_domain_status(email), to: MailDomain, as: :status
  defdelegate email_status(email), to: MailDomain, as: :address_status

  defdelegate mentions(markdown), to: Markdown
  defdelegate refs(markdown), to: Markdown
  defdelegate first_link(markdown), to: Markdown
  defdelegate plain_text(markdown), to: Markdown
  defdelegate excerpt(markdown, max_length), to: Markdown

  defdelegate span(name, attributes, fun), to: Trace

  @spec implements?(term(), module()) :: boolean()
  def implements?(%module{}, behaviour) do
    behaviours =
      :attributes
      |> module.module_info()
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    behaviour in behaviours
  end

  def implements?(_value, _behaviour), do: false
end
