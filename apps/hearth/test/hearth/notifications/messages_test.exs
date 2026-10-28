defmodule Hearth.Notifications.MessagesTest do
  use ExUnit.Case, async: true

  alias Faker.Company
  alias Faker.Internet
  alias Hearth.Common
  alias Hearth.Notifications.Anonymous
  alias Hearth.Notifications.CatchUp
  alias Hearth.Notifications.Channel.Mail
  alias Hearth.Notifications.CommunityInvite
  alias Hearth.Notifications.EmailChangeCode
  alias Hearth.Notifications.EmailChanged
  alias Hearth.Notifications.EmailInUse
  alias Hearth.Notifications.SignInCode
  alias Hearth.Notifications.TransferCode
  alias Hearth.TestUtils

  test "render SignInCode" do
    mail =
      SignInCode.to_mail(%SignInCode{code: "042917", ttl: 15}, %Anonymous{email: Internet.email()})

    assert {:ok, "<!doctype html>" <> _rest = html} = Mail.render(mail, mail.subject)
    assert html =~ TestUtils.escape_html(mail.greeting)
    assert html =~ ~s(src="http://localhost:5173/icon-192.png")
    refute html =~ ~r{<a [^>]*>\s*localhost\s*</a>}
    assert Mail.to_text(mail) =~ mail.greeting
  end

  test "render CommunityInvite" do
    message = %CommunityInvite{community_name: "Night Owls", inviter_name: "Ada", code: "abc"}
    mail = CommunityInvite.to_mail(message, %Anonymous{email: Internet.email()})

    assert {:ok, html} = Mail.render(mail, mail.subject)
    assert mail.subject == "Ada invited you to Night Owls"
    assert html =~ "http://localhost:5173/join/abc"
  end

  test "community invite carries the inviter's note" do
    message = %CommunityInvite{
      community_name: "Night Owls",
      inviter_name: "Ada",
      note: "Come say hi",
      code: "abc"
    }

    mail = CommunityInvite.to_mail(message, %Anonymous{email: Internet.email()})

    assert Mail.to_text(mail) =~ "Ada wrote: “Come say hi”"
  end

  test "render TransferCode" do
    message = %TransferCode{community_name: Company.name(), code: "042917", ttl: 15}
    mail = TransferCode.to_mail(message, %Anonymous{email: Internet.email()})

    assert {:ok, "<!doctype html>" <> _rest = html} = Mail.render(mail, mail.subject)
    assert html =~ TestUtils.escape_html(mail.greeting)
    assert mail.subject =~ "042917"
  end

  test "render EmailChangeCode" do
    mail =
      EmailChangeCode.to_mail(%EmailChangeCode{code: "042917", ttl: 15}, %Anonymous{
        email: Internet.email()
      })

    assert {:ok, "<!doctype html>" <> _rest = html} = Mail.render(mail, mail.subject)
    assert html =~ TestUtils.escape_html(mail.greeting)
    assert Mail.to_text(mail) =~ mail.greeting
  end

  test "render EmailInUse" do
    mail = EmailInUse.to_mail(%EmailInUse{}, %Anonymous{email: Internet.email()})

    assert {:ok, "<!doctype html>" <> _rest = html} = Mail.render(mail, mail.subject)
    assert html =~ TestUtils.escape_html(mail.greeting)
    assert Mail.to_text(mail) =~ mail.greeting
  end

  test "render EmailChanged" do
    mail =
      EmailChanged.to_mail(
        %EmailChanged{new_email: "new@example.com", undo_token: "undo-token", ttl: 10_080},
        %Anonymous{email: Internet.email()}
      )

    assert {:ok, "<!doctype html>" <> _rest = html} = Mail.render(mail, mail.subject)
    assert html =~ TestUtils.escape_html(mail.greeting)
    assert Mail.to_text(mail) =~ mail.greeting
  end

  test "sign in code shows the code" do
    mail = SignInCode.to_mail(%SignInCode{code: "042917", ttl: 15}, %Anonymous{email: "a@b.co"})

    assert {:ok, html} = Mail.render(mail, mail.subject)
    assert html =~ "042917"
    assert mail.subject =~ "042917"
  end

  test "email changed hides undo token" do
    message = %EmailChanged{new_email: "new@example.com", undo_token: "undo-token", ttl: 10_080}
    mail = EmailChanged.to_mail(message, %Anonymous{email: "old@example.com"})

    assert %URI{path: "/settings/email/undo", fragment: "token=undo-token"} =
             URI.parse(mail.action_url)
  end

  test "render CatchUp" do
    community = %{id: Common.new_id(), name: "Night Owls", slug: "night-owls"}
    author = %Hearth.Accounts.User{username: "ada", display_name: "Ada"}

    posts =
      for title <- ["Moths at dusk", "Best red torch"] do
        %{
          post: %{
            id: Common.new_id(),
            title: title,
            pinned_at: nil,
            reply_count: 4,
            helpful_count: 1
          },
          author: author
        }
      end

    message = %CatchUp{
      period: :weekly,
      communities: [%{community: community, posts: posts, more: 3}]
    }

    mail = CatchUp.to_mail(message, %Anonymous{email: Internet.email()})

    assert {:ok, html} = Mail.render(mail, mail.subject)
    assert mail.subject == "5 new posts in Night Owls"
    assert html =~ "Moths at dusk"
    assert html =~ "3 more in Night Owls"
    assert html =~ "http://localhost:5173/c/night-owls/p/"

    assert html =~
             ~r{turn it off in\s*<a [^>]*href="http://localhost:5173/settings"[^>]*>Settings</a>\.}

    assert Mail.to_text(mail) =~ "Ada · 4 replies · 1 helpful"
    assert Mail.to_text(mail) =~ "turn it off in Settings at http://localhost:5173/settings"
  end

  test "no email hides address" do
    to = %Anonymous{email: Internet.email()}
    community = %{id: Common.new_id(), name: "Night Owls", slug: "night-owls"}

    post = %{
      id: Common.new_id(),
      title: "Moths",
      pinned_at: nil,
      reply_count: 0,
      helpful_count: 0
    }

    messages = [
      %SignInCode{code: "042917", ttl: 15},
      %EmailChangeCode{code: "042917", ttl: 15},
      %EmailChanged{new_email: Internet.email(), undo_token: "token", ttl: 60 * 24 * 7},
      %EmailInUse{},
      %CommunityInvite{community_name: "Night Owls", inviter_name: "Ada", code: "abc"},
      %CatchUp{
        period: :daily,
        communities: [%{community: community, posts: [%{post: post, author: nil}], more: 0}]
      }
    ]

    for %module{} = message <- messages do
      mail = module.to_mail(message, to)
      {:ok, html} = Mail.render(mail, mail.subject)

      words =
        html
        |> String.replace(~r{<head>.*</head>}s, "")
        |> String.replace(~r{If the button doesn't work.*?</span>}s, "")
        |> String.replace(~r{<[^>]*>}, " ")

      refute words =~ "http", "#{inspect(module)} writes out an address"
    end
  end
end
