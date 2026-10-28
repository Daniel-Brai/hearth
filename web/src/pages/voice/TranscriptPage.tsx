import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useParams, useSearchParams } from 'react-router';
import {
  Button,
  ButtonLink,
  Chip,
  EmptyState,
  ExternalButtonLink,
  Icon,
  IconButton,
  Link,
  Measure,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { VideoPlayer, type VideoPlayerHandle } from '@/design-system/components/video-player';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { community, displayName, shortName, transcriptionOn } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { PageHeader } from '@/shell/PageHeader';
import { PersonAvatar, PersonName } from '@/shell/people';
import { secondsOf } from '@/domain/clock';
import type { TranscriptStatus } from '@/domain/types';
import './TranscriptPage.css';

const lineId = (t: string) => 't-' + t.split(':').join('-');

function highlight(text: string, query: string): ReactNode[] {
  const needle = query.trim().toLowerCase();

  if (!needle) return [text];

  const hay = text.toLowerCase();
  const out: ReactNode[] = [];
  let from = 0;

  for (let at = hay.indexOf(needle); at !== -1; at = hay.indexOf(needle, from)) {
    if (at > from) out.push(text.slice(from, at));

    out.push(<mark key={at}>{text.slice(at, at + needle.length)}</mark>);
    from = at + needle.length;
  }

  if (from < text.length) out.push(text.slice(from));

  return out;
}

function emptyText(needle: string, speaker: string | null, speakerName: string | null) {
  if (!needle) {
    return {
      title: `${speakerName ?? 'That person'} didn't speak in this session`,
      text: 'Pick Everyone above to see the whole conversation.',
    };
  }

  return {
    title: 'Nobody said that',
    text: speaker === null ? 'Try fewer words.' : 'Try fewer words, or pick Everyone above.',
  };
}

export function TranscriptPage() {
  const { session: id } = useParams();
  const on = useAppState(transcriptionOn);

  if (!id) return <ErrorPage code={404} />;
  if (!on) return <TranscriptsOff />;

  return <TranscriptLoader id={id} />;
}

function TranscriptsOff() {
  return (
    <>
      <PageHeader label="the transcript" title="Transcript" noindex />

      <main id="main">
        <Measure read>
          <EmptyState
            art="voice"
            title="Transcripts are off on this instance"
            text="Whoever runs it hasn't turned on transcription, so voice rooms keep no written record."
          />
        </Measure>
      </main>
    </>
  );
}

function TranscriptLoader({ id }: { readonly id: string }) {
  const gateway = useGateway();

  useLoad(() => gateway.load.transcript(id), 'transcript:' + id);

  const exists = useAppState((state) => !!state.transcripts[id]);

  if (!exists) return <ErrorPage code={404} />;

  return <TranscriptView id={id} />;
}

function TranscriptView({ id }: { readonly id: string }) {
  const flash = useUi((s) => s.flash);
  const [search] = useSearchParams();
  const player = useRef<VideoPlayerHandle>(null);
  const [current, setCurrent] = useState<string | null>(null);

  const [filter, setFilter] = useState('');
  const [speaker, setSpeaker] = useState<string | null>(null);

  const view = useAppState((state) => {
    const t = state.transcripts[id]!;
    const rec = t.recording ? state.recordings[t.recording] : undefined;

    return {
      cid: t.c,
      room: t.room,
      title: t.title,
      date: t.date,
      duration: t.duration,
      postId: t.postId,
      status: t.status ?? 'ready',
      speakers: t.speakers,
      lines: t.lines,
      communityName: community(state, t.c)?.name ?? null,
      recording: rec
        ? {
            duration: rec.duration,
            screen: rec.screen,
            by: displayName(state, rec.by),
            url: rec.url ?? null,
            download: rec.download ?? rec.url ?? null,
          }
        : null,
    };
  });

  const seek = search.get('t');

  useEffect(() => {
    if (!seek) return;

    const seconds = Number(seek);

    if (Number.isFinite(seconds)) player.current?.seek(seconds);
  }, [seek]);

  const starts = view.lines.map((l) => ({ t: l.t, at: secondsOf(l.t) }));

  /* Runs every frame while playing so state only changes with the line */
  const follow = (seconds: number) => {
    const line = starts.findLast((s) => s.at <= seconds)?.t ?? null;
    setCurrent((was) => (was === line ? was : line));
  };

  const needle = filter.trim().toLowerCase();

  const lines = view.lines.filter(
    (l) =>
      (speaker === null || l.who === speaker) && (!needle || l.text.toLowerCase().includes(needle)),
  );

  const speakerName = useAppState((state) =>
    speaker === null ? null : displayName(state, speaker),
  );

  const copyLink = () => {
    navigator.clipboard.writeText(window.location.href).then(
      () => flash('Link copied'),
      () => flash("Couldn't copy the link"),
    );
  };

  const empty = emptyText(needle, speaker, speakerName);

  return (
    <>
      <PageHeader
        label="the transcript"
        eyebrow="Transcript"
        title={view.room}
        endActions={
          <IconButton
            id="transcript-copy"
            onClick={copyLink}
            aria-label="Copy link"
            data-tip="Copy link"
          >
            <Icon name="link" />
          </IconButton>
        }
      />

      <main id="main">
        <Measure read className="transcript">
          <header className="post-head">
            <h2 className="post-title">{view.title}</h2>

            <div className="small subtle flex flex-wrap items-center justify-center gap-2">
              <div className="avatar-stack">
                {view.speakers.map((who) => (
                  <PersonAvatar key={who} id={who} size="xs" />
                ))}
              </div>
              <span>
                {[view.date, view.duration, view.communityName]
                  .filter((x) => x !== null)
                  .join(' · ')}
              </span>
            </div>

            <div className="flex flex-wrap items-center justify-center gap-2">
              {view.postId ? (
                <ButtonLink
                  id="transcript-post"
                  size="small"
                  to={routes.post(view.cid, view.postId)}
                >
                  <Icon name="chat" />
                  Read the post and replies
                </ButtonLink>
              ) : null}

              <ButtonLink id="transcript-make-post" size="small" to={routes.communityNew(view.cid)}>
                <Icon name="pen" />
                Make a post from this
              </ButtonLink>
            </div>
          </header>

          {view.recording ? (
            <div className="mb-4 grid gap-3">
              <div id="transcript-recording" className="recording-card text-[length:1rem]">
                <span className="recording-card__thumb">
                  <Icon name="video" />
                </span>

                <div className="grid min-w-0">
                  <strong className="truncate">Recording</strong>
                  <span className="x-small subtle">
                    {`${view.recording.duration}${view.recording.screen ? ' · includes the shared screen' : ' · audio'} · recorded by ${view.recording.by}`}
                  </span>
                </div>

                {view.recording.url ? (
                  <ExternalButtonLink
                    size="small"
                    href={view.recording.download ?? view.recording.url}
                    download={view.title + '.mp4'}
                  >
                    <Icon name="download" />
                    Download
                  </ExternalButtonLink>
                ) : null}
              </div>

              {view.recording.url ? (
                <VideoPlayer
                  ref={player}
                  id="transcript-player"
                  src={view.recording.url}
                  title={view.title}
                  audioOnly={!view.recording.screen}
                  duration={secondsOf(view.recording.duration)}
                  onTime={follow}
                />
              ) : null}
            </div>
          ) : null}

          {view.status === 'ready' ? null : <NotReady status={view.status} />}

          {/* The scroll area is padded at the top so pinning above it leaves no gap for lines to show */}
          <div className="sticky top-[calc(var(--block-space)*-1)] z-[2] -mx-[0.6rem] grid gap-3 bg-[var(--color-canvas)] px-[0.6rem] py-[0.6rem]">
            <div className="input-with-prefix rounded-full pe-4">
              <span className="inline-grid">
                <Icon name="search" />
              </span>

              <input
                className="input ps-[0.6rem]"
                id="t-search"
                type="search"
                value={filter}
                onChange={(e) => setFilter(e.target.value)}
                placeholder="Search what was said"
                aria-label="Search the transcript"
              />

              <span className="x-small subtle tabular whitespace-nowrap">
                {lines.length} of {view.lines.length}
              </span>
            </div>

            <div className="chips">
              <Chip on={speaker === null} onClick={() => setSpeaker(null)}>
                Everyone
              </Chip>

              {view.speakers.map((who) => (
                <SpeakerChip
                  key={who}
                  id={who}
                  on={speaker === who}
                  onPick={() => setSpeaker(who)}
                />
              ))}
            </div>
          </div>

          <div id="transcript-lines">
            {lines.map((l) => (
              <div
                key={l.id ?? l.t + l.who}
                id={lineId(l.t)}
                className="transcript__line"
                data-current={l.t === current ? '' : undefined}
              >
                <div className="t">
                  <Link
                    to={
                      view.recording?.url
                        ? { search: `?t=${secondsOf(l.t)}`, hash: '#' + lineId(l.t) }
                        : { hash: '#' + lineId(l.t) }
                    }
                    replace
                    aria-label={'Go to ' + l.t}
                  >
                    {l.t}
                  </Link>
                </div>

                <div>
                  <div className="transcript__speaker">
                    <PersonName id={l.who} />
                  </div>
                  {l.editable && l.id ? (
                    <EditableLine sessionId={id} lineId={l.id} text={l.text} filter={filter} />
                  ) : (
                    <p>{highlight(l.text, filter)}</p>
                  )}
                </div>
              </div>
            ))}

            {lines.length || view.status !== 'ready' ? null : (
              <EmptyState art="search" title={empty.title} text={empty.text} />
            )}
          </div>
        </Measure>
      </main>
    </>
  );
}

function SpeakerChip({
  id,
  on,
  onPick,
}: {
  readonly id: string;
  readonly on: boolean;
  readonly onPick: () => void;
}) {
  const name = useAppState((state) => shortName(state, id));

  return (
    <Chip on={on} onClick={onPick}>
      <PersonAvatar id={id} size="xs" />
      <span>{name}</span>
    </Chip>
  );
}

function NotReady({ status }: { readonly status: TranscriptStatus }) {
  if (status === 'failed')
    return (
      <EmptyState
        art="broken"
        title="This transcript couldn't be written"
        text="The recording is still here to watch. Whoever runs this instance can look into why."
      />
    );

  return (
    <EmptyState
      art="voice"
      title="The transcript is being written"
      text="It takes a few minutes once the recording is ready. This fills in by itself when it's done."
    />
  );
}

// The box takes the cursor when it opens so the fix can start right away
const focusOnOpen = (box: HTMLTextAreaElement | null) => box?.focus();

function EditableLine({
  sessionId,
  lineId,
  text,
  filter,
}: {
  readonly sessionId: string;
  readonly lineId: string;
  readonly text: string;
  readonly filter: string;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const [draft, setDraft] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const save = async () => {
    if (draft === null) return;

    setSaving(true);

    try {
      const result = await gateway.voice.editTranscriptLine(sessionId, lineId, draft);

      if (result.ok) setDraft(null);
      else flash(result.error);
    } finally {
      setSaving(false);
    }
  };

  if (draft === null)
    return (
      <div className="transcript__editable">
        <p>{highlight(text, filter)}</p>
        <IconButton
          variant="borderless"
          size="tiny"
          className="transcript__edit"
          onClick={() => setDraft(text)}
          aria-label="Fix this line"
          data-tip="Fix this line"
        >
          <Icon name="pencil" />
        </IconButton>
      </div>
    );

  return (
    <form
      className="transcript__form"
      onSubmit={(e) => {
        e.preventDefault();
        void save();
      }}
    >
      <textarea
        className="input"
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        aria-label="What was said"
        rows={Math.min(6, Math.ceil(draft.length / 70) + 1)}
        ref={focusOnOpen}
      />
      <div className="flex justify-end gap-2">
        <Button size="small" variant="borderless" onClick={() => setDraft(null)}>
          Cancel
        </Button>
        <Button size="small" variant="reversed" type="submit" busy={saving} disabled={saving}>
          Save
        </Button>
      </div>
    </form>
  );
}
