defmodule Hearth.Notifications.Worker.DeliverMailTest do
  use Hearth.DataCase, async: true

  import Swoosh.TestAssertions

  alias Faker.Internet
  alias Faker.Lorem
  alias Faker.Person
  alias Hearth.Notifications.Delivery
  alias Hearth.Notifications.SealedArgs
  alias Hearth.Notifications.Worker.DeliverMail

  describe "enqueue/2" do
    test "keeps mail out of job args" do
      email = Internet.email()
      code = "#{Enum.random(100_000..999_999)}"
      mail = %{to: [nil, email], subject: "#{code} is your code", html: code, text: code}

      assert {:ok, _job} =
               mail
               |> Map.put(:template, "login")
               |> Map.put(:user_id, nil)
               |> DeliverMail.enqueue()

      assert [job] = all_enqueued(worker: DeliverMail)

      refute inspect(job.args) =~ email
      refute inspect(job.args) =~ code
      assert %{"to" => [nil, ^email], "template" => "login"} = DeliverMail.mail(job)
    end
  end

  describe "perform/1" do
    test "send email" do
      name = Person.name()
      email = Internet.email()
      text = Lorem.sentence()
      mail = %{to: [name, email], subject: Lorem.sentence(), html: "<p>#{text}</p>", text: text}
      args = %{template: "hello", user_id: nil, sealed: SealedArgs.seal(mail)}

      assert :ok = perform_job(DeliverMail, args)
      assert_email_sent(to: [{name, email}], subject: mail.subject, text_body: text)
      assert [%Delivery{status: :sent, template: "hello"}] = Delivery.all(to: email)
    end
  end
end
