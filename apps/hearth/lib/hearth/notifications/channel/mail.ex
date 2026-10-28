defmodule Hearth.Notifications.Channel.Mail do
  @behaviour Hearth.Notifications.Channel

  alias Hearth.Accounts.User
  alias Hearth.Notifications
  alias Hearth.Notifications.MailMessage
  alias Hearth.Notifications.Notifiable
  alias Hearth.Notifications.Template
  alias Hearth.Notifications.View
  alias Hearth.Notifications.Worker.DeliverMail

  @impl Hearth.Notifications.Channel
  def name, do: :mail

  # Queued so a provider outage retries instead of losing the email
  @impl Hearth.Notifications.Channel
  def send(%module{} = message, %_{} = notifiable) do
    mail = module.to_mail(message, notifiable)
    subject = mail.subject || Notifications.title(module)

    with {:ok, html} <- render(mail, subject) do
      args = %{
        subject: subject,
        html: html,
        text: to_text(mail),
        template: Notifications.template_name(module),
        user_id: user_id(notifiable)
      }

      notifiable
      |> Notifiable.recipients(name())
      |> List.wrap()
      |> Enum.each(fn {name, email} ->
        args
        |> Map.put(:to, [name, email])
        |> DeliverMail.enqueue()
      end)
    end
  end

  @spec render(MailMessage.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def render(%MailMessage{} = mail, subject) do
    mail = in_order(mail)

    assigns =
      mail
      |> Map.from_struct()
      |> Map.merge(%{
        subject: subject,
        preview: mail.preview || first_line(mail.intro_lines),
        brand: Notifications.brand(),
        icon: Notifications.brand_icon(),
        url: Notifications.url("/")
      })

    assigns
    |> View.email()
    |> Template.to_html()
  end

  @spec to_text(MailMessage.t()) :: String.t()
  def to_text(%MailMessage{} = mail) do
    mail = in_order(mail)
    action = if mail.action_text, do: "#{mail.action_text}: #{mail.action_url}"

    [
      mail.greeting,
      Enum.map(mail.intro_lines, &line_text/1),
      Enum.map(mail.sections, &section_text/1),
      action,
      mail.code,
      Enum.map(mail.outro_lines, &line_text/1),
      "#{Notifications.brand()} · #{Notifications.url("/")}"
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp line_text({:link, before, text, url}), do: "#{before}#{text} at #{url}"
  defp line_text(line), do: line

  defp section_text(section) do
    items = Enum.map(section.items, &"#{&1.title}\n#{&1.meta}\n#{&1.url}")
    more = with {text, url} <- section.more, do: "#{text}\n#{url}"

    [String.upcase(section.heading) | items]
    |> Enum.concat(List.wrap(more))
    |> Enum.join("\n\n")
  end

  # MailMessage prepends so lines and sections come back newest first
  defp in_order(mail) do
    %{
      mail
      | intro_lines: Enum.reverse(mail.intro_lines),
        sections: Enum.reverse(mail.sections),
        outro_lines: Enum.reverse(mail.outro_lines)
    }
  end

  defp first_line([line | _rest]) when is_binary(line), do: line
  defp first_line(_lines), do: nil

  defp user_id(%User{id: id}), do: id
  defp user_id(_notifiable), do: nil
end
