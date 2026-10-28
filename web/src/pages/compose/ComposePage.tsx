import { useEffect, useState, type KeyboardEvent } from 'react';
import { useParams } from 'react-router';
import { ButtonLink, EmptyState, Icon, Measure, Textarea } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import type { AppState } from '@/domain/app-state';
import { canDo, isTech, joinedCids, kindInfo, postableKinds } from '@/domain/selectors';
import type { Attachment } from '@/domain/types';
import { Composer } from '@/features/composer/Composer';
import { extractTags } from '@/features/markdown/tags';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import {
  CommunityAndKind,
  ModeToggle,
  PostPreview,
  PublishBar,
  SaveBadge,
  TagsRow,
} from './ComposeParts';
import { LeaveDialog } from './LeaveDialog';
import { hasContent, useComposeDraft } from './use-compose-draft';
import { useLeaveGuard } from './use-leave-guard';
import { usePublish } from './use-publish';
import './ComposePage.css';
import { TITLE_MAX } from '@/domain/catalog';

const allowedCommunities = (state: AppState) =>
  joinedCids(state).filter((id) => canDo(state, id, 'post.create'));

export function ComposePage() {
  const { community: asked } = useParams();
  const gateway = useGateway();

  useLoad(() => gateway.load.compose(), 'compose');

  const allowed = useAppState((state) => allowedCommunities(state));

  const askedName = useAppState((state) =>
    asked ? (state.communities[asked]?.name ?? null) : null,
  );

  const cid = asked && allowed.includes(asked) ? asked : (allowed[0] ?? null);

  const flash = useUi((s) => s.flash);

  useEffect(() => {
    if (asked && askedName && asked !== cid) flash(`Join ${askedName} to post there`);
  }, [asked, askedName, cid, flash]);

  if (!cid) {
    return (
      <>
        <PageHeader label="new post" title="New post" />
        <main id="main">
          <Measure narrow>
            <EmptyState
              art="posts"
              title="There is nowhere to post yet"
              text="Join a community, then write your first post there."
            >
              <div className="flex justify-center">
                <ButtonLink to={routes.home} variant="reversed">
                  <Icon name="inbox" />
                  Go to Catch up
                </ButtonLink>
              </div>
            </EmptyState>
          </Measure>
        </main>
      </>
    );
  }

  return <ComposeForm key={cid} initialCid={cid} />;
}

function titleKeyHandler(publish: () => void) {
  return (e: KeyboardEvent) => {
    if (e.key !== 'Enter') return;
    e.preventDefault();

    if (e.metaKey || e.ctrlKey) publish();
    else document.getElementById('compose-body')?.focus();
  };
}

function ComposeForm({ initialCid }: { readonly initialCid: string }) {
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);

  const draft = useComposeDraft(initialCid);
  const { fields, saveState, edit } = draft;

  const [files, setFiles] = useState<Attachment[]>([]);
  const [preview, setPreview] = useState(false);

  const dirty =
    saveState === 'Saving…' || saveState === "Couldn't save the draft" || files.length > 0;
  const guard = useLeaveGuard(dirty);

  const { busy, shake, publish } = usePublish({
    fields,
    files,
    onPublished: () => {
      draft.published();
      guard.allowLeave();
    },
  });

  const communities = useAppState(
    (state) =>
      allowedCommunities(state).map((id) => ({ value: id, label: state.communities[id]!.name })),
    () => false,
  );

  const communityName = useAppState((state) => state.communities[fields.cid]?.name ?? null);
  const kinds = useAppState((state) => postableKinds(state, fields.cid));
  const kind = useAppState((state) => kindInfo(state, fields.cid, fields.kind));
  const tech = useAppState((state) => isTech(state, fields.cid));

  const tags = useAppState((state) =>
    extractTags(state, fields.title + ' ' + fields.body, fields.cid),
  );

  const discard = () =>
    ask({
      title: 'Discard this draft?',
      body: 'The title and text you wrote will be deleted.',
      action: 'Discard',
      onConfirm: () => {
        draft.clear();
        setFiles([]);
        flash('Draft discarded');
      },
    });

  const badge = saveState ? <SaveBadge saveState={saveState} /> : null;

  return (
    <>
      <PageHeader
        label="new post"
        title="New post"
        endActions={badge ? <span className="hide-mobile">{badge}</span> : null}
      />

      <main id="main">
        <Measure narrow className="grid gap-4">
          <CommunityAndKind
            cid={fields.cid}
            communities={communities}
            kinds={kinds}
            kind={fields.kind}
            description={kind.desc}
            onCommunity={draft.changeCommunity}
            onKind={(k) => edit({ kind: k })}
          />

          <Textarea
            id="compose-title"
            bare
            className="compose-title"
            rows={1}
            value={fields.title}
            onChange={(e) => edit({ title: e.target.value })}
            onKeyDown={titleKeyHandler(() => void publish())}
            maxLength={TITLE_MAX}
            countFrom={TITLE_MAX - 30}
            shake={shake}
            placeholder={kind.hint}
            aria-label="Title"
            autoFocus
          />

          <ModeToggle preview={preview} onChange={setPreview} />

          <div hidden={preview}>
            <Composer
              id="compose-body"
              variant="body"
              value={fields.body}
              onChange={(body) => edit({ body })}
              onSubmit={() => void publish()}
              placeholder={kind.body + (tech ? ' Code goes in ``` fences.' : '')}
              sendLabel="Post"
              maxLength={20000}
              community={fields.cid}
              attachments={files}
              onAttachmentsChange={setFiles}
            />
          </div>

          {preview ? (
            <PostPreview cid={fields.cid} title={fields.title} body={fields.body} files={files} />
          ) : null}

          {tags.length ? <TagsRow tags={tags} /> : null}

          <PublishBar
            canDiscard={hasContent(fields)}
            badge={saveState}
            busy={busy}
            communityName={communityName}
            onDiscard={discard}
            onPublish={() => void publish()}
          />
        </Measure>
      </main>

      <LeaveDialog
        blocker={guard.blocker}
        title="Leave without posting?"
        text={
          files.length
            ? "Attachments aren't kept with a draft, so they would be lost."
            : "Your latest changes haven't been saved yet."
        }
        stay="Keep writing"
        leave="Leave"
      />
    </>
  );
}
