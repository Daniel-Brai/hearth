# Sign in at /dev/mailbox with a code. Seeded people, all at example.com
#   mira_member    a plain member
#   remy_remover   a Member plus a "Tidy crew" role with only content.remove
#   bea_banner     a Member plus a "Door" role with only member.ban
#   troll_tom      posts what gets reported, ready to be banned
#   dana_dm        sends the reported direct message
# The owner of "Moderation Lab" is SEED_OWNER (default danielbrai), which must already exist

alias Hearth.Accounts
alias Hearth.Chat
alias Hearth.Communities
alias Hearth.Forum
alias Hearth.Moderation

if Mix.env() != :dev, do: raise("The seed is for the dev database only")

Logger.configure(level: :info)

defmodule Seed do
  @moduledoc false

  def user!(username, display_name) do
    case Accounts.get_user(username: username) do
      {:ok, user} ->
        user

      {:error, :not_found} ->
        {:ok, user} =
          Accounts.register_user(%{
            username: username,
            email: "#{username}@example.com",
            display_name: display_name
          })

        user
    end
  end

  # Nothing in the app makes someone an instance admin but being the first account, so the seed sets it.
  def instance_admin!(user) do
    user
    |> Ecto.Changeset.change(is_instance_admin: true)
    |> Hearth.Repo.update!()
  end

  def community!(owner, slug, params) do
    case Communities.get_community(slug: slug) do
      {:ok, community} ->
        community

      {:error, :not_found} ->
        {:ok, community} = Communities.start_community(owner, params)
        community
    end
  end

  def empty?(community), do: Forum.list_posts(community).data == []

  def kinds!(community, tries \\ 20) do
    case Forum.list_kinds(community.id) do
      [] when tries > 0 ->
        Process.sleep(100)
        kinds!(community, tries - 1)

      [] ->
        {:ok, kinds} = Forum.create_default_kinds(community.id, community.template)
        kinds

      kinds ->
        kinds
    end
  end

  def member!(community, user) do
    case Communities.join(user, community) do
      {:ok, _membership} -> :ok
      {:error, _already} -> :ok
    end
  end

  def role!(owner, community, member, key, name, permissions) do
    _role =
      Communities.create_role(owner, community, %{key: key, name: name, permissions: permissions})

    {:ok, _membership} = Communities.set_member_roles(owner, community, member, ["member", key])
    :ok
  end

  def room(community, slug) do
    community |> Communities.list_rooms() |> Enum.find(&(&1.slug == slug))
  end

  def post!(author, community, kind, title, body) do
    {:ok, post} =
      Forum.create_post(author, community, %{kind_id: kind.id, title: title, body: body})

    post
  end

  def reply!(author, post, body, parent \\ nil) do
    params = %{body: body, parent_reply_id: parent && parent.id}
    {:ok, reply} = Forum.reply(author, post, params)
    reply
  end

  def say!(author, place, body) do
    {:ok, message} = Chat.send_message(author, place, %{body: body})
    message
  end

  def report!(reporter, type, id, reason, note) do
    {:ok, _item} = Moderation.report(reporter, type, id, %{reason: reason, note: note})
    :ok
  end
end

defmodule Seed.Run do
  @moduledoc false

  def run(owner) do
    owner = if owner.is_instance_admin, do: owner, else: Seed.instance_admin!(owner)
    people = people!()
    {lab, quiet} = communities!(owner, people)

    lab_content!(owner, lab, people)
    quiet_content!(quiet, people)
    direct_message!(people)

    Mix.shell().info("Seeded Moderation Lab (moderation-lab) and Quiet Corner (quiet-corner).")
  end

  defp people! do
    %{
      mira: Seed.user!("mira_member", "Mira Member"),
      remy: Seed.user!("remy_remover", "Remy Remover"),
      bea: Seed.user!("bea_banner", "Bea Banner"),
      tom: Seed.user!("troll_tom", "Troll Tom"),
      dana: Seed.user!("dana_dm", "Dana DM")
    }
  end

  defp communities!(owner, people) do
    lab =
      Seed.community!(owner, "moderation-lab", %{
        name: "Moderation Lab",
        tagline: "A place to try reports, the queue and bans",
        template: "oss",
        visibility: :public
      })

    quiet =
      Seed.community!(owner, "quiet-corner", %{
        name: "Quiet Corner",
        tagline: "Not moderated, so nothing here can be reported",
        template: "club",
        visibility: :public
      })

    for person <- Map.values(people), community <- [lab, quiet] do
      Seed.member!(community, person)
    end

    if lab.moderation != :reports do
      {:ok, _lab} = Moderation.set_level(owner, lab, :reports)
    end

    :ok = Seed.role!(owner, lab, people.remy, "tidy-crew", "Tidy crew", ["content.remove"])
    :ok = Seed.role!(owner, lab, people.bea, "door", "Door", ["member.ban"])

    has_voice = lab |> Communities.list_rooms() |> Enum.any?(&(&1.type == :voice))

    if not has_voice do
      {:ok, _voice} = Communities.create_room(owner, lab, %{name: "Office hours", type: :voice})
    end

    {lab, quiet}
  end

  defp lab_content!(owner, lab, people) do
    if Seed.empty?(lab), do: lab_posts!(owner, lab, people)
  end

  defp lab_posts!(owner, lab, %{mira: mira, remy: remy, bea: bea, tom: tom, dana: dana}) do
    [kind | _kinds] = Seed.kinds!(lab)

    welcome =
      Seed.post!(owner, lab, kind, "Welcome to the lab", """
      This community exists to try moderation by hand. Report things, work the queue, ban and unban.
      """)

    spam =
      Seed.post!(tom, lab, kind, "Cheap followers, click here now", """
      Buy 10,000 followers for five dollars at a link I will not paste here. Limited time only.
      """)

    first = Seed.reply!(mira, welcome, "Glad this exists. Where do reports go?")

    second =
      Seed.reply!(owner, welcome, "Into the queue for anyone who can remove content.", first)

    third = Seed.reply!(mira, welcome, "And people with only the ban permission?", second)
    _fourth = Seed.reply!(bea, welcome, "We see the log and the banned list.", third)

    rude =
      Seed.reply!(
        tom,
        welcome,
        "Nobody cares, this whole place is pathetic and so are you.",
        first
      )

    general = Seed.room(lab, "general")
    _hello = Seed.say!(mira, general, "Morning everyone.")
    insult = Seed.say!(tom, general, "Mira you are an idiot and should leave.")
    _calm = Seed.say!(remy, general, "Let's keep it kind in here.")

    :ok = Seed.report!(mira, :post, spam.id, "spam", "Selling followers.")
    :ok = Seed.report!(dana, :post, spam.id, "spam", nil)
    :ok = Seed.report!(mira, :reply, rude.id, "harassment", "Aimed at everyone.")
    :ok = Seed.report!(mira, :message, insult.id, "harassment", "Called me an idiot.")
  end

  defp quiet_content!(quiet, %{mira: mira}) do
    if Seed.empty?(quiet) do
      [kind | _kinds] = Seed.kinds!(quiet)

      _post =
        Seed.post!(mira, quiet, kind, "Nothing here can be reported", """
        This community is set to None, so the Report action is hidden.
        """)
    end
  end

  defp direct_message!(%{dana: dana, tom: tom}) do
    case Chat.list_conversations(dana) do
      [] ->
        {:ok, direct} = Chat.start_direct(dana, tom)
        _hi = Seed.say!(dana, direct, "Hi Tom, saw your post in the lab.")
        threat = Seed.say!(tom, direct, "Report me again and you will regret it.")

        :ok =
          Seed.report!(dana, :message, threat.id, "harassment", "A threat in my direct messages.")

      _conversations ->
        :ok
    end
  end
end

owner_name = System.get_env("SEED_OWNER", "danielbrai")

case Accounts.get_user(username: owner_name) do
  {:ok, owner} ->
    Seed.Run.run(owner)

  {:error, :not_found} ->
    Mix.shell().info("Skipped the dev seed. Sign up as #{owner_name} first, or set SEED_OWNER.")
end
