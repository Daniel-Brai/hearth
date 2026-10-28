defmodule Hearth.Notifications.Channel.MailTest do
  use Hearth.DataCase, async: true

  alias Faker.Internet
  alias Hearth.Notifications.Anonymous
  alias Hearth.Notifications.Channel.Mail
  alias Hearth.TestUtils

  defmodule Login do
    use Hearth.Notifications.Message

    alias Hearth.Notifications.MailMessage

    defstruct []

    @impl Hearth.Notifications.Message
    def via(%__MODULE__{}, _notifiable), do: [:mail]

    @impl Hearth.Notifications.Message
    def to_mail(%__MODULE__{}, _notifiable) do
      %MailMessage{}
      |> MailMessage.greeting("Hi")
      |> MailMessage.line("Someone signed in to your account.")
      |> MailMessage.action("Review your sessions", "https://hearth.example.com")
    end
  end

  describe "send/2" do
    test "queues email without account" do
      email = Internet.email()

      assert :ok = Mail.send(%Login{}, %Anonymous{email: email})

      assert TestUtils.mail_enqueued?(%{
               to: [nil, email],
               subject: "Login",
               template: "login",
               user_id: nil
             })
    end

    test "queues email for person" do
      user = TestUtils.register_random_user!()

      assert :ok = Mail.send(%Login{}, user)

      assert TestUtils.mail_enqueued?(%{to: [user.display_name, user.email], user_id: user.id})
    end
  end

  describe "render/2" do
    test "makes a full email page with the button" do
      mail = Login.to_mail(%Login{}, %Anonymous{email: Internet.email()})

      assert {:ok, "<!doctype html>" <> _rest = html} = Mail.render(mail, "Login")
      assert html =~ "Review your sessions"
    end
  end
end
