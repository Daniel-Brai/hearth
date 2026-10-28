defmodule Hearth.AccountsTest do
  use Hearth.DataCase, async: true

  alias Faker.Internet
  alias Faker.Lorem
  alias Faker.Person
  alias Hearth.Accounts
  alias Hearth.Accounts.AvatarChanged
  alias Hearth.Accounts.Privacy
  alias Hearth.Accounts.Settings
  alias Hearth.Accounts.Taken
  alias Hearth.Accounts.User
  alias Hearth.Common
  alias Hearth.Common.Link
  alias Hearth.TestUtils

  setup do
    params = %{
      username: TestUtils.random_username(),
      email: Internet.email(),
      display_name: Person.name()
    }

    {:ok, user} = Accounts.register_user(params)

    _state = :sys.get_state(Taken)

    {:ok, binding()}
  end

  describe "list_people/4" do
    test "puts online people first unless they hide it" do
      users = Stream.repeatedly(&TestUtils.register_random_user!/0)
      [hidden, online, offline] = Enum.take(users, 3)

      {:ok, _privacy} = Accounts.update_privacy(hidden, %{presence: :nobody})
      ids = [hidden.id, online.id, offline.id]

      assert [first | _rest] = Accounts.list_people("", ids, [hidden.id, online.id], 10)
      assert first.id == online.id
    end

    test "puts the closest match first" do
      user = TestUtils.register_random_user!()
      other = TestUtils.register_random_user!()

      assert [%{id: id} | _rest] =
               Accounts.list_people(user.username, [other.id, user.id], [], 10)

      assert id == user.id
    end
  end

  describe "register_user/1" do
    test "fails if username is invalid" do
      params = %{username: "no spaces", email: Internet.email()}

      assert {:error, changeset} = Accounts.register_user(params)
      assert %{username: [_message]} = errors_on(changeset)
    end

    test "fails if email is invalid" do
      params = %{username: TestUtils.random_username(), email: "not-an-email"}

      assert {:error, changeset} = Accounts.register_user(params)
      assert %{email: ["is not a valid email"]} = errors_on(changeset)
    end

    test "fails if username is taken", %{user: user} do
      params = %{username: String.upcase(user.username), email: Internet.email()}

      assert {:error, changeset} = Accounts.register_user(params)
      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end

    test "fails if email is taken", %{user: user} do
      params = %{username: TestUtils.random_username(), email: String.upcase(user.email)}

      assert {:error, changeset} = Accounts.register_user(params)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "register user", %{user: user} do
      assert %User{settings: %Settings{}, privacy: %Privacy{}, links: []} = user
      assert %Settings{theme: :system, digest: :weekly} = user.settings
      assert %Privacy{show_communities: :common, presence: :everyone} = user.privacy
      assert Taken.member?(:username, user.username)
      assert Taken.member?(:email, user.email)
    end

    test "first account is instance admin", %{user: first} do
      {:ok, second} =
        Accounts.register_user(%{username: TestUtils.random_username(), email: Internet.email()})

      assert first.is_instance_admin
      refute second.is_instance_admin
    end
  end

  describe "get_user/1" do
    test "fails if user does not exist" do
      assert {:error, :not_found} = Accounts.get_user(id: Common.new_id())
    end

    test "get user", %{user: user} do
      assert {:ok, %User{id: id}} = Accounts.get_user(username: user.username)
      assert id == user.id
    end
  end

  describe "list_users/1" do
    test "leaves out unknown and deleted people" do
      %{id: id} = user = TestUtils.register_random_user!()
      deleted = TestUtils.register_random_user!()
      :ok = TestUtils.update_rows!(User, [id: deleted.id], deleted_at: DateTime.utc_now())

      assert [%User{id: ^id}] = Accounts.list_users([user.id, deleted.id, Common.new_id()])
    end

    test "lists each person once" do
      user = TestUtils.register_random_user!()

      assert [%User{}] = Accounts.list_users([user.id, user.id])
    end
  end

  describe "search_users/3" do
    test "finds no one outside the ids given", %{user: user} do
      assert [] = Accounts.search_users(user.username, [Common.new_id()], 5)
    end

    test "matches username start or name part" do
      ada = TestUtils.register_random_user!(username: "ada_l", display_name: "Ada Lovelace")
      grace = TestUtils.register_random_user!(username: "grace_h", display_name: "Grace Hopper")
      ids = [ada.id, grace.id]

      assert [%User{username: "ada_l"}] = Accounts.search_users("ad", ids, 5)
      assert [%User{username: "grace_h"}] = Accounts.search_users("hop", ids, 5)
    end

    test "forgives a typo" do
      grace = TestUtils.register_random_user!(username: "grace_h", display_name: "Grace Hopper")

      assert [%User{username: "grace_h"}] = Accounts.search_users("hoper", [grace.id], 5)
    end

    test "ranks username matches first" do
      exact = TestUtils.register_random_user!(username: "ada_l", display_name: "Someone")
      named = TestUtils.register_random_user!(username: "lovelace", display_name: "Ada Lovelace")

      assert [first, second] = Accounts.search_users("ada", [named.id, exact.id], 5)
      assert first.id == exact.id
      assert second.id == named.id
    end

    test "lists everyone by username for an empty query" do
      zed = TestUtils.register_random_user!(username: "zed_z")
      amy = TestUtils.register_random_user!(username: "amy_a")

      assert [%User{username: "amy_a"}, %User{username: "zed_z"}] =
               Accounts.search_users("", [zed.id, amy.id], 5)
    end
  end

  describe "update_profile/2" do
    test "fails if bio is too long", %{user: user} do
      params = %{bio: String.duplicate("a", 301)}

      assert {:error, changeset} = Accounts.update_profile(user, params)
      assert %{bio: ["should be at most 300 character(s)"]} = errors_on(changeset)
    end

    test "saves nothing if a link is not a web address", %{user: user} do
      params = %{bio: Lorem.sentence(), links: [%{url: "ftp://example.com"}]}

      assert {:error, changeset} = Accounts.update_profile(user, params)
      assert %{links: [%{url: ["must be a web address"]}]} = errors_on(changeset)
      assert {:ok, %User{bio: nil}} = Accounts.get_user(id: user.id)
    end

    test "ignores username", %{user: user} do
      assert {:ok, updated} =
               Accounts.update_profile(user, %{username: TestUtils.random_username()})

      assert updated.username == user.username
    end

    test "update profile", %{user: user} do
      params = %{bio: Lorem.sentence(), pronouns: "they/them"}

      assert {:ok, %User{} = updated} = Accounts.update_profile(user, params)
      assert updated.bio == params.bio
      assert updated.pronouns == params.pronouns
    end

    test "changes links and privacy with the profile", %{user: user} do
      url = Internet.url()

      params = %{
        "bio" => Lorem.sentence(),
        "links" => [%{"url" => url, "label" => Lorem.word()}],
        "privacy" => %{"presence" => "nobody"}
      }

      assert {:ok, %User{links: [link], privacy: privacy} = updated} =
               Accounts.update_profile(user, params)

      assert updated.bio == params["bio"]
      assert link.url == url
      assert %Privacy{presence: :nobody, avatar: :everyone} = privacy
    end

    test "says nothing when the avatar stays", %{user: user} do
      %{id: user_id} = user
      :ok = Accounts.subscribe_to_pubsub()

      assert {:ok, _user} = Accounts.update_profile(user, %{bio: Lorem.sentence()})

      refute_receive %AvatarChanged{user_id: ^user_id}
    end

    test "tells others the avatar changed", %{user: user} do
      %{id: user_id} = user
      avatar_id = Common.new_id()
      :ok = Accounts.subscribe_to_pubsub()

      assert {:ok, _user} = Accounts.update_profile(user, %{avatar_id: avatar_id})

      assert_receive %AvatarChanged{user_id: ^user_id, avatar_id: ^avatar_id}
    end
  end

  describe "change_email/2" do
    test "fails if email is invalid", %{user: user} do
      assert {:error, changeset} = Accounts.change_email(user, "not-an-email")
      assert %{email: ["is not a valid email"]} = errors_on(changeset)
    end

    test "fails if email is taken", %{user: user} do
      other = TestUtils.register_random_user!()

      assert {:error, changeset} = Accounts.change_email(user, other.email)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "change email", %{user: user} do
      email = Internet.email()

      assert {:ok, %User{email_confirmed_at: %DateTime{}} = updated} =
               Accounts.change_email(user, String.upcase(email))

      assert updated.email == String.downcase(email)

      _state = :sys.get_state(Taken)
      assert Accounts.email_registered?(email)
    end
  end

  describe "update_settings/2" do
    test "fails if theme is unknown", %{user: user} do
      assert {:error, changeset} = Accounts.update_settings(user, %{theme: "neon"})
      assert %{settings: %{theme: ["is invalid"]}} = errors_on(changeset)
    end

    test "update settings", %{user: user} do
      params = %{theme: "dark", captions_on: true, digest: "off"}

      assert {:ok, %Settings{theme: :dark, captions_on: true, digest: :off}} =
               Accounts.update_settings(user, params)
    end

    test "turn haptics off", %{user: user} do
      assert %Settings{haptics: true} = user.settings
      assert {:ok, %Settings{haptics: false}} = Accounts.update_settings(user, %{haptics: false})
    end
  end

  describe "update_privacy/2" do
    test "fails if audience is unknown", %{user: user} do
      assert {:error, changeset} = Accounts.update_privacy(user, %{presence: "friends"})
      assert %{privacy: %{presence: ["is invalid"]}} = errors_on(changeset)
    end

    test "update privacy", %{user: user} do
      params = %{presence: "nobody", show_name: false}

      assert {:ok, %Privacy{presence: :nobody, show_name: false}} =
               Accounts.update_privacy(user, params)
    end
  end

  describe "replace_links/2" do
    test "fails if url is not a web address", %{user: user} do
      url = Internet.url()
      {:ok, user} = Accounts.replace_links(user, [%{url: url}])
      links = [%{url: Internet.url()}, %{url: "ftp://#{Internet.domain_name()}"}]

      assert {:error, changeset} = Accounts.replace_links(user, links)
      assert %{links: errors} = errors_on(changeset)
      assert %{url: ["must be a web address"]} in errors
      assert {:ok, %User{links: [%Link{url: ^url}]}} = Accounts.get_user(id: user.id)
    end

    test "replace links", %{user: user} do
      site = Internet.url()
      code = Internet.url()
      label = Lorem.word()
      links = [%{"url" => site, "label" => label}, %{"url" => code}, %{"url" => site}]

      assert {:ok, %User{links: [first, second]}} = Accounts.replace_links(user, links)
      assert %Link{url: ^site, label: ^label} = first
      assert %Link{url: ^code, label: nil} = second
      assert {:ok, %User{links: [^first, ^second]}} = Accounts.get_user(id: user.id)
    end
  end

  describe "username_available?/1" do
    test "fails if username is invalid" do
      refute Accounts.username_available?("no")
      refute Accounts.username_available?("no spaces")
    end

    test "fails if username is taken", %{user: user} do
      refute Accounts.username_available?(user.username)
      refute user.username |> String.upcase() |> Accounts.username_available?()
    end

    test "returns true if username is free" do
      assert Accounts.username_available?(TestUtils.random_username())
    end
  end

  describe "email_registered?/1" do
    test "returns false if email is unknown" do
      refute Accounts.email_registered?(Internet.email())
    end

    test "returns true if email is registered", %{user: user} do
      assert user.email |> String.upcase() |> Accounts.email_registered?()
    end
  end
end
