defmodule Hearth.TestUtils do
  use Oban.Testing, repo: Hearth.Repo, prefix: "oban"

  import Ecto.Query
  import ExUnit.Callbacks

  alias ExRTP.Packet
  alias ExWebRTC.Media.IVF
  alias ExWebRTC.Media.Ogg
  alias ExWebRTC.RTP.Payloader
  alias ExWebRTC.RTPCodecParameters
  alias Faker.Internet
  alias Faker.Lorem
  alias Faker.Person
  alias Hearth.Accounts
  alias Hearth.Auth
  alias Hearth.Auth.TransferCodeRequested
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.Forum
  alias Hearth.Media
  alias Hearth.Notifications
  alias Hearth.Notifications.Channel.Mail
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.Worker.DeliverMail
  alias Hearth.RateLimit
  alias Hearth.Repo
  alias Hearth.RTC
  alias Hearth.RTC.Recorder
  alias Hearth.Storage
  alias Hearth.Transcripts.Transcript
  alias Hearth.Transcripts.Worker.Transcribe
  alias Hearth.Voice
  alias Hearth.Voice.Capture
  alias Hearth.Voice.Command.StartRecording
  alias Hearth.Voice.Command.StopRecording
  alias Hearth.Voice.Live
  alias Hearth.Voice.LiveSupervisor
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Session
  alias Phoenix.HTML
  alias Vix.Vips.MutableImage

  def random_username, do: "user_#{System.unique_integer([:positive])}"

  def random_key, do: 32 |> :crypto.strong_rand_bytes() |> Base.encode64()

  def random_github_release(tag) do
    %{
      "tag_name" => tag,
      "name" => "Hearth #{tag}",
      "html_url" => "https://github.com/daniel-brai/hearth/releases/tag/#{tag}",
      "body" => Lorem.paragraph(),
      "published_at" => "2026-10-20T10:00:00Z"
    }
  end

  def register_random_user!(opts \\ []) do
    params = %{
      username: opts[:username] || random_username(),
      email: opts[:email] || Internet.email(),
      display_name: opts[:display_name] || Person.name()
    }

    {:ok, user} = Accounts.register_user(params)

    _state = :sys.get_state(Hearth.Accounts.Taken)

    # Each test starts with no accounts so its first would be the instance admin
    admin = Keyword.get(opts, :admin, false)

    if user.is_instance_admin != admin do
      update_rows!(Hearth.Accounts.User, [id: user.id], is_instance_admin: admin)
    end

    %{user | is_instance_admin: admin}
  end

  def random_push_sub_params(
        endpoint \\ "https://push.example.com/#{System.unique_integer([:positive])}"
      ) do
    {public_key, _private_key} = :crypto.generate_key(:ecdh, :prime256v1)

    %{
      endpoint: endpoint,
      p256dh: Base.url_encode64(public_key, padding: false),
      auth:
        16
        |> :crypto.strong_rand_bytes()
        |> Base.url_encode64(padding: false)
    }
  end

  def link_random_push_sub!(user) do
    {:ok, subscription} = Notifications.link_push_sub(user, random_push_sub_params())

    subscription
  end

  def create_random_community!(owner \\ nil, opts \\ []) do
    owner = owner || register_random_user!()

    params =
      Map.merge(
        %{name: "Community #{System.unique_integer([:positive])}", template: "blank"},
        Map.new(opts)
      )

    {:ok, community} = Communities.start_community(%{owner | is_instance_admin: true}, params)

    community
  end

  def join_random_member!(community) do
    member = register_random_user!()
    {:ok, _membership} = Communities.join(member, community)

    member
  end

  def join_with_permissions!(community, permissions) do
    member = join_random_member!(community)
    {:ok, owner} = Accounts.get_user(id: community.owner_id)
    key = "role-#{System.unique_integer([:positive])}"

    {:ok, _role} =
      Communities.create_role(owner, community, %{
        key: key,
        name: Lorem.word(),
        permissions: permissions
      })

    {:ok, _membership} = Communities.set_member_roles(owner, community, member, [key])

    member
  end

  def create_random_forum!(owner \\ nil, opts \\ []) do
    community = create_random_community!(owner, Keyword.put_new(opts, :template, "oss"))
    {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)

    community
  end

  def put_community_creation(mode) when mode in ~w[admins request anyone] do
    previous = Application.fetch_env!(:hearth, Communities)
    on_exit(fn -> Application.put_env(:hearth, Communities, previous) end)

    Application.put_env(:hearth, Communities, creation: mode)
  end

  def create_random_post!(author, community, opts \\ []) do
    [kind | _kinds] = Forum.list_kinds(community.id)

    params =
      Map.merge(
        %{kind_id: kind.id, title: Lorem.sentence(), body: Lorem.paragraph()},
        Map.new(opts)
      )

    {:ok, post} = Forum.create_post(author, community, params)

    post
  end

  def random_upload_params(data, content_type, opts \\ []) do
    sha256 =
      :sha256
      |> :crypto.hash(data)
      |> Base.encode16(case: :lower)

    Map.merge(
      %{
        idempotency_key: Common.new_id(),
        name: "file",
        content_type: content_type,
        byte_size: byte_size(data),
        sha256: sha256
      },
      Map.new(opts)
    )
  end

  def random_png!(width, height) do
    width
    |> Image.new!(height, color: :orange)
    |> Image.write!(:memory, suffix: ".png")
  end

  # A JPEG stored on its side, as a phone does, carrying who took it
  def photo_with_metadata!(width, height) do
    {:ok, image} =
      width
      |> Image.new!(height, color: :orange)
      |> Image.mutate(fn image ->
        :ok = MutableImage.set(image, "orientation", :gint, 6)
        :ok = MutableImage.set(image, "exif-ifd0-Artist", :gchararray, "Somebody")
      end)

    Image.write!(image, :memory, suffix: ".jpg")
  end

  def stored_image!(key), do: key |> Storage.local_path() |> Image.open!()

  # The container's own tags, such as a title or where it was filmed
  def video_tags!(key) do
    {json, 0} =
      System.cmd(
        "ffprobe",
        Enum.concat(~w[-v error -print_format json -show_format], [Storage.local_path(key)]),
        env: %{"SECRET_KEY_BASE" => nil}
      )

    json |> JSON.decode!() |> get_in(~w[format tags]) || %{}
  end

  def upload_random_file!(uploader, data, content_type, opts \\ []) do
    {:ok, %{media: requested}} =
      Media.request_upload(uploader, random_upload_params(data, content_type, opts))

    :ok = Storage.put(requested.bucket_key, data, content_type)
    {:ok, media} = Media.complete_upload(uploader, requested)

    media
  end

  def random_video!(opts \\ []) do
    size = Keyword.get(opts, :size, "320x240")
    seconds = Keyword.get(opts, :seconds, 2)
    codecs = Keyword.get(opts, :codecs, ~w[-c:v libx264 -preset ultrafast -c:a aac])
    format = Keyword.get(opts, :format, "mp4")
    dir = Path.join(System.tmp_dir!(), "hearth-video-#{System.unique_integer([:positive])}")
    path = Path.join(dir, "clip.#{format}")
    File.mkdir_p!(dir)

    sources =
      ~w[-f lavfi -i testsrc=duration=#{seconds}:size=#{size}:rate=5] ++
        ~w[-f lavfi -i sine=duration=#{seconds}]

    {_output, 0} =
      System.cmd("ffmpeg", ~w[-v error -y] ++ sources ++ codecs ++ ["-shortest", path],
        env: %{"SECRET_KEY_BASE" => nil}
      )

    data = File.read!(path)
    File.rm_rf!(dir)

    data
  end

  def stored_value!(schema, id, field) do
    [value] =
      schema
      |> where(id: ^id)
      |> select([row], type(field(row, ^field), :binary))
      |> Repo.all()

    value
  end

  def update_rows!(schema, filters, changes) do
    {_count, _rows} =
      schema
      |> where(^filters)
      |> Repo.update_all(set: changes)

    :ok
  end

  def put_screening(changes) do
    {policy, screener} = Keyword.split(changes, [:screener, :image_floor])

    for {key, changes} <- [
          {Hearth.ScreeningPolicy, policy},
          {Hearth.Moderation.Screener, screener}
        ],
        changes != [] do
      previous = Application.fetch_env!(:hearth, key)
      on_exit(fn -> Application.put_env(:hearth, key, previous) end)
      Application.put_env(:hearth, key, Keyword.merge(previous, changes))
    end

    :ok
  end

  def put_transcription(mode) do
    previous = Application.fetch_env!(:hearth, Hearth.TranscriptionPolicy)

    on_exit(fn ->
      Application.put_env(:hearth, Hearth.TranscriptionPolicy, previous)
    end)

    Application.put_env(:hearth, Hearth.TranscriptionPolicy, Keyword.put(previous, :mode, mode))

    :ok
  end

  def roll_back!(fun) do
    {:error, :rolled_back} =
      Repo.transaction(fn ->
        fun.()
        Repo.rollback(:rolled_back)
      end)

    :ok
  end

  def chat_completion(content) do
    message = %{"role" => "assistant", "content" => Jason.encode!(content)}
    %{"choices" => [%{"message" => message}]}
  end

  def minutes_ago(minutes), do: DateTime.add(DateTime.utc_now(), -minutes, :minute)

  def days_ago(days), do: DateTime.add(DateTime.utc_now(), -days, :day)

  def get_room!(community, filters) do
    community
    |> Communities.list_rooms()
    |> Enum.find(fn room ->
      Enum.all?(filters, fn {key, value} -> Map.fetch!(room, key) == value end)
    end)
  end

  def reply_created(reply, post, author) do
    %Hearth.Forum.ReplyCreated{
      reply_id: reply.id,
      post_id: post.id,
      parent_reply_id: nil,
      community_id: post.community_id,
      author_id: author.id,
      parent_author_id: nil,
      post_author_id: post.author_id
    }
  end

  def create_random_communities!(owner, count) do
    Enum.map(1..count, fn _index -> create_random_community!(owner) end)
  end

  def create_random_reply_chain!(author, post, parent, depth) do
    Enum.reduce(1..depth, parent, fn _level, parent ->
      {:ok, reply} =
        Forum.reply(author, post, %{body: Lorem.sentence(), parent_reply_id: parent.id})

      reply
    end)
  end

  def random_ids(count) do
    ids = Stream.repeatedly(&Common.new_id/0)
    Enum.take(ids, count)
  end

  def upload_random_attachments!(uploader, count) do
    Enum.map(1..count, fn _index ->
      upload_random_file!(uploader, Lorem.paragraph(), "text/plain", name: "notes.txt")
    end)
  end

  def request_random_uploads!(uploader, data, content_type, count) do
    Enum.map(1..count, fn _index ->
      {:ok, %{media: media}} =
        Media.request_upload(uploader, random_upload_params(data, content_type))

      media
    end)
  end

  def transfer_code!(%{id: id} = owner, community) do
    :ok = Auth.subscribe_to_pubsub()
    :ok = Communities.request_transfer_code(owner, community)

    receive do
      %TransferCodeRequested{user_id: ^id, code: code} -> code
    after
      1_000 -> raise "no transfer code was sent"
    end
  end

  def verify_wrong_codes!(email, count) do
    Enum.each(1..count, fn _index ->
      {:error, :invalid} = Auth.verify_sign_in_code(email, "wrong")
    end)
  end

  def spend_rate_limit!(key, scale, limit) do
    Enum.each(1..limit, fn _index -> {:allow, _count} = RateLimit.hit(key, scale, limit) end)
  end

  def escape_html(text) do
    text
    |> HTML.html_escape()
    |> HTML.safe_to_string()
  end

  def fail_random_uploads!(uploader, data, content_type, count) do
    Enum.each(1..count, fn _index ->
      [media] = request_random_uploads!(uploader, data, content_type, 1)
      update_rows!(Hearth.Media.Asset, [id: media.id], status: :failed)
    end)
  end

  def create_random_community_event!(host, community, opts \\ []) do
    params =
      Map.merge(
        %{
          title: Lorem.sentence(),
          starts_at: DateTime.add(DateTime.utc_now(), 2, :day),
          duration_min: 60,
          timezone: "Africa/Lagos",
          place: :room,
          room_id: get_room!(community, type: :voice).id
        },
        Map.new(opts)
      )

    {:ok, event} = Events.schedule_event(host, community, params)

    event
  end

  def create_random_notification!(user, opts \\ []) do
    params =
      Map.merge(
        %{kind: :event_reminder, subject_type: "event", subject_id: Common.new_id()},
        Map.new(opts)
      )

    {:ok, notification} =
      Notification.insert(%Notification{user_id: user.id}, params)

    notification
  end

  def create_random_notifications!(user, count, opts \\ []) do
    now = DateTime.utc_now()

    rows =
      for _index <- 1..count do
        Map.merge(
          %{
            id: Common.new_id(),
            user_id: user.id,
            kind: :event_reminder,
            subject_type: "event",
            subject_id: Common.new_id(),
            data: %{},
            inserted_at: now,
            updated_at: now
          },
          Map.new(opts)
        )
      end

    {^count, _rows} = Repo.insert_all(Notification, rows)

    :ok
  end

  def pluck(items, field), do: Enum.map(items, &Map.fetch!(&1, field))

  def out_of_order(values) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reject(fn [before, next] -> before <= next end)
  end

  def out_of_order(items, field), do: items |> pluck(field) |> out_of_order()

  def long_silences(silences, min_ms) do
    Enum.filter(silences, fn {from, to} -> is_integer(to) and to - from >= min_ms end)
  end

  def start_servings!(servings) do
    for {module, serving} <- servings do
      start_supervised!({Nx.Serving, serving: serving, name: module, batch_size: 1})
    end
  end

  def spoken_text(segments), do: segments |> pluck(:text) |> Enum.join(" ") |> String.downcase()

  def stored(items), do: Enum.filter(items, &match?({:ok, _object}, Storage.head(&1.key)))

  # The messages whose mail writes out a web address outside the button and its fallback line
  def mails_with_addresses(messages, to) do
    for %module{} = message <- messages,
        mail = module.to_mail(message, to),
        {:ok, html} = Mail.render(mail, mail.subject),
        html
        |> String.replace(~r{<head>.*</head>}s, "")
        |> String.replace(~r{If the button doesn't work.*?</span>}s, "")
        |> String.replace(~r{<[^>]*>}, " ")
        |> String.contains?("http"),
        do: module
  end

  def child_names(children) do
    Enum.map(children, fn
      %{id: id} -> id
      {module, _arg} -> module
      module -> module
    end)
  end

  def oban_queues(children) do
    Enum.find_value(children, fn
      {Oban, opts} -> Keyword.fetch!(opts, :queues)
      _other -> nil
    end)
  end

  # Mail jobs seal the address and content so assert_enqueued/1 sees only user_id and template
  @spec mail_enqueued?(map()) :: boolean()
  def mail_enqueued?(%{} = match) do
    wanted = Map.new(match, fn {key, value} -> {to_string(key), value} end)

    [worker: DeliverMail]
    |> all_enqueued()
    |> Enum.map(&DeliverMail.mail/1)
    |> Enum.any?(&(Map.take(&1, Map.keys(wanted)) == wanted))
  end

  # Voice runs outside the test's own supervisor, which would stop it as soon as the
  # test ends and cut an upload off mid query. It stops in on_exit instead, before
  # the test's database goes away
  def start_voice! do
    start_supervised!(Hearth.RTC.Supervisor)
    {:ok, voice} = Hearth.Voice.Supervisor.start_link()
    Process.unlink(voice)
    on_exit(fn -> stop_voice(voice) end)
    :ok = :pg.join(Hearth.Roles, :rtc, self())
  end

  defp stop_voice(voice) do
    for {_id, live, _type, _modules} <- DynamicSupervisor.which_children(LiveSupervisor) do
      DynamicSupervisor.terminate_child(LiveSupervisor, live)
    end

    Hearth.Voice.TaskSupervisor |> Task.Supervisor.children() |> Enum.each(&await_exit/1)
    Supervisor.stop(voice)
  end

  def stop_rtc! do
    :ok = :pg.leave(Hearth.Roles, :rtc, self())
  end

  def put_voice(changes) do
    previous = Application.fetch_env!(:hearth, Voice)
    on_exit(fn -> Application.put_env(:hearth, Voice, previous) end)

    Application.put_env(:hearth, Voice, Keyword.merge(previous, changes))
  end

  def put_rtc(changes) do
    previous = Application.fetch_env!(:hearth, RTC)
    on_exit(fn -> Application.put_env(:hearth, RTC, previous) end)

    Application.put_env(:hearth, RTC, Keyword.merge(previous, changes))
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    after
      10_000 -> :ok
    end
  end

  # RTP packets of 20 ms Opus silence frames, as a speaker's peer hands them over
  def opus_packets(frames) do
    for n <- 0..(frames - 1) do
      %ExRTP.Packet{
        payload_type: 111,
        sequence_number: n,
        timestamp: n * 960,
        ssrc: 1,
        payload: <<0xF8, 0xFF, 0xFE>>
      }
    end
  end

  def live_of!(session) do
    _children = DynamicSupervisor.which_children(LiveSupervisor)
    Live.whereis(session.id)
  end

  def create_random_voice_room!(community) do
    {:ok, owner} = Accounts.get_user(id: community.owner_id)

    {:ok, room} =
      Communities.create_room(owner, community, %{
        name: "Voice #{System.unique_integer([:positive])}",
        type: :voice
      })

    room
  end

  def start_random_voice_session!(community, opts \\ []) do
    room = create_random_voice_room!(community)
    {:ok, owner} = Accounts.get_user(id: community.owner_id)
    host = Keyword.get(opts, :host, owner)
    # Stage unless asked, since most voice tests are about who may talk
    params = opts |> Keyword.take([:mode, :topic]) |> Map.new() |> Map.put_new(:mode, :stage)

    {:ok, session} = Voice.start_session(host, room, params)

    session
  end

  def insert_random_voice_session!(community) do
    room = create_random_voice_room!(community)

    new = %Session{
      room_id: room.id,
      community_id: community.id,
      host_id: community.owner_id,
      node: Atom.to_string(node())
    }

    {:ok, session} = Session.insert(new, %{mode: :stage})

    session
  end

  def start_fake_channel! do
    test = self()

    spawn_link(fn ->
      receive_loop = fn loop ->
        receive do
          {:hearth_rtc, _kind, _payload} = message ->
            send(test, {:voice_channel, self(), message})
            loop.(loop)

          :stop ->
            :ok
        end
      end

      receive_loop.(receive_loop)
    end)
  end

  def await_recording_uploads! do
    for task <- Task.Supervisor.children(Hearth.Voice.TaskSupervisor) do
      ref = Process.monitor(task)

      receive do
        {:DOWN, ^ref, :process, ^task, _reason} -> :ok
      end
    end

    :ok
  end

  def send_random_audio!(session, user_id) do
    [peer] = RTC.members({:peer, session.id, user_id})
    %{pc: pc, inbound: %{audio: %{track: track}}} = :sys.get_state(peer)
    packet = Packet.new(<<0xF8, 0xFF, 0xFE>>, payload_type: 111, ssrc: 1)

    send(peer, {:ex_webrtc, pc, {:rtp, track, nil, packet}})
    _state = :sys.get_state(peer)
    :ok
  end

  def record_random_session!(session, tracks, seconds) do
    {:ok, started} = StartRecording.execute(session, session.host_id)

    for {user_id, kind, offset_ms, length} <- tracks,
        do: write_random_track!(started.id, user_id, kind, offset_ms, length)

    {:ok, stopped} = StopRecording.execute(started, session.host_id, :stopped)
    {:ok, uploaded} = Capture.upload(stopped)
    ended_at = DateTime.add(uploaded.started_at, seconds, :second)
    :ok = update_rows!(Recording, [id: uploaded.id], ended_at: ended_at)

    %{uploaded | ended_at: ended_at}
  end

  # Speech from flite saved as AAC the way a speaker's track is stored, with two seconds between phrases
  def write_speech!(phrases, dir) do
    File.mkdir_p!(dir)

    wavs =
      for {text, n} <- phrases |> List.wrap() |> Enum.with_index() do
        wav = Path.join(dir, "speech-#{n}.wav")

        {_output, 0} =
          System.cmd("flite", ["-t", text, "-o", wav], env: %{"SECRET_KEY_BASE" => nil})

        wav
      end

    inputs =
      wavs
      |> Enum.intersperse(:pause)
      |> Enum.flat_map(fn
        :pause -> ~w[-f lavfi -t 2 -i anullsrc=r=8000:cl=mono]
        wav -> ["-i", wav]
      end)

    m4a = Path.join(dir, "speech.m4a")
    count = length(wavs) * 2 - 1

    concat = ["-filter_complex", "concat=n=#{count}:v=0:a=1"]
    ffmpeg!(inputs ++ concat ++ ["-ac", "1", "-c:a", "aac", "-b:a", "64k", m4a])

    m4a
  end

  # Each speaker's file holds the stub transcriber's lines, "start_ms end_ms text"
  def insert_random_ready_recording!(session, speakers) do
    id = Common.new_id()
    now = DateTime.utc_now()

    files =
      for {user_id, lines} <- speakers do
        key = "recordings/#{id}/speakers/#{user_id}.m4a"
        :ok = Storage.put(key, lines, "audio/mp4")
        %Recording.Speaker{user_id: user_id, key: key}
      end

    {:ok, recording} =
      Repo.insert(%Recording{
        id: id,
        session_id: session.id,
        community_id: session.community_id,
        room_id: session.room_id,
        started_by_id: session.host_id,
        status: :ready,
        started_at: DateTime.add(now, -60, :second),
        ended_at: now,
        duration_ms: 60_000,
        speakers: files
      })

    recording
  end

  def transcribe_random_recording!(session, speakers) do
    recording = insert_random_ready_recording!(session, speakers)
    :ok = Transcribe.perform(%Oban.Job{args: %{"recording_id" => recording.id}, attempt: 1})

    Transcript.latest(recording_id: recording.id)
  end

  def write_random_track!(recording_id, user_id, kind, offset_ms, seconds) do
    dir = Recorder.dir(recording_id)
    n = System.unique_integer([:positive])
    source = Path.join(dir, "source-#{n}")
    File.mkdir_p!(dir)

    packets = random_rtp!(kind, source, seconds)
    File.rm!(source)

    data =
      for {ms, packet} <- packets, into: <<>> do
        encoded = Packet.encode(packet)
        <<offset_ms + ms::32, byte_size(encoded)::32, encoded::binary>>
      end

    path = Path.join(dir, "#{user_id}.#{kind}.#{n}.rtp")
    File.write!(path, data)
  end

  defp random_rtp!(:audio, source, seconds) do
    ffmpeg!(~w[-f lavfi -i sine=frequency=440:duration=#{seconds} -c:a libopus -f ogg #{source}])
    {:ok, reader} = Ogg.Reader.open(source)

    reader
    |> ogg_frames(0, [])
    |> to_rtp(%RTPCodecParameters{payload_type: 111, mime_type: "audio/opus", clock_rate: 48_000})
  end

  defp random_rtp!(:video, source, seconds) do
    ffmpeg!(
      ~w[-f lavfi -i testsrc=duration=#{seconds}:size=640x360:rate=10 -c:v libvpx -g 10] ++
        ~w[-f ivf #{source}]
    )

    {:ok, header, reader} = IVF.Reader.open(source)
    unit = header.timebase_num * 1_000 / header.timebase_denum

    reader
    |> ivf_frames(unit, [])
    |> to_rtp(%RTPCodecParameters{payload_type: 96, mime_type: "video/VP8", clock_rate: 90_000})
  end

  defp ogg_frames(reader, ms, frames) do
    case Ogg.Reader.next_packet(reader) do
      {:ok, {packet, duration}, reader} ->
        ogg_frames(reader, ms + duration, [{ms, packet} | frames])

      _end ->
        Enum.reverse(frames)
    end
  end

  defp ivf_frames(reader, unit, frames) do
    case IVF.Reader.next_frame(reader) do
      {:ok, frame} ->
        ivf_frames(reader, unit, [{round(frame.timestamp * unit), frame.data} | frames])

      _end ->
        Enum.reverse(frames)
    end
  end

  defp to_rtp(frames, codec) do
    {:ok, payloader} = Payloader.new(codec)
    per_ms = div(codec.clock_rate, 1_000)

    {packets, _payloader} =
      Enum.flat_map_reduce(frames, payloader, fn {ms, frame}, payloader ->
        {packets, payloader} = Payloader.payload(payloader, frame)
        {Enum.map(packets, &{ms, &1}), payloader}
      end)

    packets
    |> Enum.with_index()
    |> Enum.map(fn {{ms, packet}, n} ->
      {ms, %{packet | sequence_number: rem(n, 65_536), timestamp: ms * per_ms}}
    end)
  end

  defp ffmpeg!(args) do
    {_output, 0} = System.cmd("ffmpeg", ~w[-v error -y] ++ args, env: %{"SECRET_KEY_BASE" => nil})
    :ok
  end
end
