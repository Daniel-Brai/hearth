import { useRef, useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import {
  Button,
  ButtonLink,
  ExternalButtonLink,
  Icon,
  IconButton,
  Input,
  Label,
} from '@/design-system';
import { VideoPlayer } from '@/design-system/components/video-player';
import { useAppState } from '@/data/store';
import { displayName } from '@/domain/selectors';
import type { RecordingStatus } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PersonAvatar } from '@/shell/people';
import type { Row } from './recording-row';

const STATUS_TEXT: Partial<Record<RecordingStatus, string>> = {
  recording: 'Recording now',
  processing: 'Putting the video together. This takes a few minutes.',
};

type RecordingListProps = {
  readonly id: string;
  readonly label: string;
  readonly cid: string;
  readonly rows: readonly Row[];
  readonly linkPosts?: boolean;
};

export function RecordingList({ id, label, cid, rows, linkPosts = true }: RecordingListProps) {
  const [playing, setPlaying] = useState<string | null>(null);
  const [renaming, setRenaming] = useState<string | null>(null);
  const me = useAppState((state) => state.me);
  const remove = useDeleteRecording();

  if (!rows.length) return null;

  return (
    <section id={id} className="grid gap-2">
      <Label>{label}</Label>

      {rows.map((r) => (
        <div key={r.id} id={'recording-' + r.id} className="grid gap-2">
          <div className="recording-card" data-status={r.status}>
            <span className="recording-card__media">
              <span className="recording-card__thumb">
                {r.poster ? (
                  <img className="recording-card__poster" src={r.poster} alt="" loading="lazy" />
                ) : (
                  <Icon name={r.status === 'failed' ? 'info' : 'video'} />
                )}
              </span>
              {r.by ? <RecordedBy id={r.by} /> : null}
            </span>

            <div className="grid min-w-0">
              {renaming === r.id ? (
                <RenameForm id={r.id} title={r.title} onDone={() => setRenaming(null)} />
              ) : (
                <strong className="truncate">{r.title}</strong>
              )}
              <span className="x-small subtle">{r.meta}</span>
              {STATUS_TEXT[r.status] ? (
                <span className="x-small icon-text recording-card__status" role="status">
                  <span className="rec-dot" />
                  {STATUS_TEXT[r.status]}
                </span>
              ) : null}
              {r.status === 'failed' ? (
                <span className="x-small recording-card__failure">
                  {r.failure ?? "This recording couldn't be saved."}
                </span>
              ) : null}
            </div>

            <div className="recording-card__actions">
              {r.url ? (
                <Button
                  id={'recording-play-' + r.id}
                  size="small"
                  on={playing === r.id}
                  aria-expanded={playing === r.id}
                  aria-label={playing === r.id ? 'Close' : 'Play'}
                  data-tip={playing === r.id ? 'Close' : 'Play'}
                  onClick={() => setPlaying((was) => (was === r.id ? null : r.id))}
                >
                  <Icon name={playing === r.id ? 'x' : 'play'} />
                  <span className="recording-card__label">
                    {playing === r.id ? 'Close' : 'Play'}
                  </span>
                </Button>
              ) : null}

              {r.url ? (
                <ExternalButtonLink
                  id={'recording-download-' + r.id}
                  size="small"
                  href={r.download ?? r.url}
                  download={r.title + '.mp4'}
                  aria-label="Download"
                  data-tip="Download"
                >
                  <Icon name="download" />
                  <span className="recording-card__label">Download</span>
                </ExternalButtonLink>
              ) : null}

              {r.by === me && renaming !== r.id ? (
                <IconButton
                  id={'recording-rename-' + r.id}
                  onClick={() => setRenaming(r.id)}
                  aria-label="Rename recording"
                  data-tip="Rename"
                >
                  <Icon name="pencil" />
                </IconButton>
              ) : null}

              {r.by === me && r.status !== 'recording' ? (
                <IconButton
                  id={'recording-delete-' + r.id}
                  onClick={() => remove(r.id)}
                  aria-label="Delete recording"
                  data-tip="Delete"
                >
                  <Icon name="trash" />
                </IconButton>
              ) : null}

              {linkPosts && r.postId ? (
                <ButtonLink
                  size="small"
                  to={routes.post(cid, r.postId)}
                  aria-label="View post"
                  data-tip="View post"
                >
                  <Icon name="chat" />
                  <span className="recording-card__label">View post</span>
                </ButtonLink>
              ) : null}
            </div>
          </div>

          {r.url && playing === r.id ? (
            <VideoPlayer
              id={'recording-player-' + r.id}
              src={r.url}
              title={r.title}
              audioOnly={!r.screen}
              duration={r.seconds}
              autoPlay
            />
          ) : null}
        </div>
      ))}
    </section>
  );
}

function RecordedBy({ id }: { readonly id: string }) {
  const name = useAppState((state) => displayName(state, id));

  return (
    <span
      className="recording-card__by"
      role="img"
      aria-label={'Recorded by ' + name}
      data-tip={'Recorded by ' + name}
    >
      <PersonAvatar id={id} size="sm" />
    </span>
  );
}

// Enter saves and Escape puts the old title back
function RenameForm({
  id,
  title,
  onDone,
}: {
  readonly id: string;
  readonly title: string;
  readonly onDone: () => void;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const field = useRef<HTMLInputElement>(null);
  // Escape unmounts the field, which blurs it, and that blur must not save
  const cancelled = useRef(false);

  const save = async () => {
    const next = field.current?.value.trim() ?? '';
    if (cancelled.current || !next || next === title) return onDone();

    const r = await gateway.voice.renameRecording(id, next);
    if (!r.ok) flash(r.error);
    onDone();
  };

  return (
    <form
      id={'recording-rename-form-' + id}
      className="recording-card__rename"
      onSubmit={(e) => {
        e.preventDefault();
        void save();
      }}
    >
      <Input
        id={'recording-title-' + id}
        aria-label="Recording title"
        ref={field}
        defaultValue={title}
        maxLength={200}
        autoFocus
        onBlur={() => void save()}
        onKeyDown={(e) => {
          if (e.key !== 'Escape') return;
          cancelled.current = true;
          onDone();
        }}
      />
    </form>
  );
}

function useDeleteRecording() {
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);

  return (id: string) =>
    ask({
      title: 'Delete this recording?',
      body: 'Its video and transcript are removed for everyone. This cannot be undone.',
      action: 'Delete recording',
      onConfirm: () =>
        void gateway.voice
          .deleteRecording(id)
          .then((r) => flash(r.ok ? 'Recording deleted' : r.error)),
    });
}
