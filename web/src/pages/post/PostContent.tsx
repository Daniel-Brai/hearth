import { ButtonLink, FileList, Icon, Link, LiveDot, OriginNote, Pill } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useDisplayZone } from '@/app/request-context';
import { TITLE_LONG } from '@/domain/catalog';
import { ageText, dateText, plural } from '@/domain/format';
import { attachmentSrc, type Post } from '@/domain/types';
import { useAppState } from '@/data/store';
import { recordingsFor } from '@/domain/selectors';
import { Boosts } from '@/features/boosts/BoostMenu';
import { Markdown } from '@/features/markdown/Markdown';
import { RecordingList } from '@/features/recordings/RecordingList';
import { toRow } from '@/features/recordings/recording-row';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { useFlashFailure } from '@/runtime/use-flash-failure';
import { useGuest } from '@/shell/use-guest';
import { PersonAvatar, PersonLink } from '@/shell/people';
import type { PostViewData } from './use-post-view';

type PostProps = { readonly post: Post; readonly view: PostViewData };

export function PostHeading({ post, view }: PostProps) {
  const zone = useDisplayZone();

  return (
    <header className="post-head">
      <div className="flex items-center gap-2 flex-wrap justify-center">
        <Pill tint={view.kindHue}>
          {post.answer ? (
            <span className="pill__check">
              <Icon name="check" />
            </span>
          ) : null}
          <span>{post.kind + (post.answer ? ' · Answered' : '')}</span>
        </Pill>
        {post.pinned ? (
          <span className="kicker-icon" data-tip="Pinned" aria-label="Pinned">
            <Icon name="pin" />
          </span>
        ) : null}
        {post.locked ? (
          <span className="kicker-icon" id="post-locked" data-tip="Locked" aria-label="Locked">
            <Icon name="lock" />
          </span>
        ) : null}
      </div>

      <h2 className="post-title" data-long={post.title.length > TITLE_LONG || undefined}>
        {post.title}
      </h2>

      <PersonLink id={post.author} className="byline">
        <PersonAvatar id={post.author} size="sm" />
        <strong>{view.authorName}</strong>
        <span className="subtle">{ageText(post.age)}</span>
        {post.editedAt ? (
          <span
            className="subtle x-small"
            id="post-edited"
            data-tip={'Edited ' + dateText(post.editedAt, zone, true)}
          >
            edited
          </span>
        ) : null}
      </PersonLink>
    </header>
  );
}

export function PostOrigins({ post, view }: PostProps) {
  const who = post.author === view.me ? 'you and the moderators' : 'moderators and its author';

  return (
    <div className="grid gap-2 mb-5">
      {post.moderated ? (
        <OriginNote id="post-removed-note">
          <Icon name="shield" />
          <span>Removed by a moderator. Only {who} can see it.</span>
        </OriginNote>
      ) : null}
      {post.pending ? (
        <OriginNote id="post-pending-note">
          <Icon name="eye" />
          <span>Held for review. Only {who} can see it until it's kept.</span>
        </OriginNote>
      ) : null}

      {view.live ? <LiveNote post={post} live={view.live} /> : null}

      {post.fromChat ? (
        <OriginNote oneLine>
          <span className="origin-note__text">
            <Icon name="chat" />
            <span>
              Started as <strong>{plural(post.fromChat.count, 'message')}</strong> in #
              {post.fromChat.room}
            </span>
          </span>
          <ButtonLink size="tiny" to={routes.chat(post.c, post.fromChat.room)}>
            Open chat
          </ButtonLink>
        </OriginNote>
      ) : null}

      {view.transcript ? (
        <OriginNote oneLine>
          <span className="origin-note__text">
            <Icon name="captions" />
            <span className="truncate">
              <span className="hide-narrow">Talked through live in </span>
              <span className="show-narrow">Live in </span>
              <strong>{view.transcript.room}</strong> · {view.transcript.duration}
              {view.recorded ? ', recorded' : ''}
            </span>
          </span>
          <ButtonLink size="tiny" to={routes.session(post.c, view.transcript.id)}>
            Transcript
          </ButtonLink>
        </OriginNote>
      ) : null}

      <PostRecordings post={post} />
    </div>
  );
}

function PostRecordings({ post }: { readonly post: Post }) {
  const rows = useAppState((state) => recordingsFor(state, post.id).map((r) => toRow(r)));

  return (
    <RecordingList
      id="post-recordings"
      label={rows.length > 1 ? 'Live discussions' : 'The live discussion'}
      cid={post.c}
      rows={rows}
      linkPosts={false}
    />
  );
}

function LiveNote({
  post,
  live,
}: {
  readonly post: Post;
  readonly live: NonNullable<PostViewData['live']>;
}) {
  return (
    <OriginNote live oneLine>
      <span className="origin-note__text">
        <LiveDot />
        <strong>Live room on this post</strong>
      </span>
      <span className="listen-actions">
        <span
          className="listen-count"
          data-tip={plural(live.listeners, 'person listening', 'people listening')}
          aria-label={live.listeners + ' listening'}
        >
          <Icon name="users" />
          <span>{live.listeners}</span>
        </span>
        <ButtonLink size="tiny" to={routes.voice(post.c, live.id)}>
          <Icon name="volume" />
          <span>{live.mode === 'open' ? 'Join' : 'Listen in'}</span>
        </ButtonLink>
      </span>
    </OriginNote>
  );
}

export function PostBody({ post }: { readonly post: Post }) {
  const gateway = useGateway();
  const settle = useFlashFailure();
  const openImage = useUi((s) => s.openImage);
  const { viewer, signIn } = useGuest();

  const looseFiles = (post.files ?? []).filter(
    (f) => !post.body.join('\n').includes(`attachment:${f.id}`),
  );

  return (
    <>
      <Markdown
        className="post-body"
        text={post.body}
        community={post.c}
        files={post.files ?? []}
      />

      {looseFiles.length ? (
        <div className="post-files mt-3">
          <FileList
            files={looseFiles}
            onOpenImage={(f) => openImage(attachmentSrc(f), f.name, f.download)}
          />
        </div>
      ) : null}

      {post.tags.length ? (
        <div className="tags mt-4 text-small">
          {post.tags.map((t) => (
            <Link key={t} className="ref ref--tag" to={routes.tag(post.c, t)}>
              #{t}
            </Link>
          ))}
        </div>
      ) : null}

      <Boosts
        className="mt-4"
        boosts={post.boosts}
        disabled={viewer === 'unknown'}
        onToggle={
          viewer === 'member' ? (key) => settle(gateway.posts.toggleBoost(post.id, key)) : signIn
        }
      />
    </>
  );
}
