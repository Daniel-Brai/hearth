import { Button, FileList, Icon, Label, Panel, Segmented, Select, cn } from '@/design-system';
import type { Attachment, PostKind } from '@/domain/types';
import { Markdown } from '@/features/markdown/Markdown';
import { useUi } from '@/runtime/ui-store';
import { KindPicker } from './KindPicker';
import type { SaveState } from './use-compose-draft';
import { TITLE_LONG } from '@/domain/catalog';

export function SaveBadge({ saveState }: { readonly saveState: SaveState }) {
  return (
    <span className={cn('save-state', saveState === 'Saving…' && 'is-saving')}>
      {saveState !== 'Saving…' ? <Icon name="check" /> : null}
      <span>{saveState}</span>
    </span>
  );
}

export function CommunityAndKind({
  cid,
  communities,
  kinds,
  kind,
  description,
  onCommunity,
  onKind,
}: {
  readonly cid: string;
  readonly communities: { value: string; label: string }[];
  readonly kinds: readonly PostKind[];
  readonly kind: string;
  readonly description: string | null | undefined;
  readonly onCommunity: (cid: string) => void;
  readonly onKind: (kind: string) => void;
}) {
  return (
    <div className="grid gap-2 justify-items-center">
      <div className="posting-in flex items-center gap-2 small subtle">
        <span className="shrink-0 whitespace-nowrap">Posting in</span>
        <Select inline value={cid} options={communities} onChange={onCommunity} label="Community" />
      </div>

      <KindPicker kinds={kinds} value={kind} onChange={onKind} />

      {description ? <p className="x-small subtle text-center">{description}</p> : null}
    </div>
  );
}

export function ModeToggle({
  preview,
  onChange,
}: {
  readonly preview: boolean;
  readonly onChange: (preview: boolean) => void;
}) {
  return (
    <div className="flex justify-center">
      <Segmented
        name="mode"
        value={preview ? 'preview' : 'write'}
        onChange={(v) => onChange(v === 'preview')}
        label="Write or preview"
        options={[
          {
            value: 'write',
            label: (
              <>
                <Icon name="pencil" />
                Write
              </>
            ),
          },
          {
            value: 'preview',
            label: (
              <>
                <Icon name="eye" />
                Preview
              </>
            ),
          },
        ]}
      />
    </div>
  );
}

export function PostPreview({
  cid,
  title,
  body,
  files,
}: {
  readonly cid: string;
  readonly title: string;
  readonly body: string;
  readonly files: readonly Attachment[];
}) {
  const openImage = useUi((s) => s.openImage);
  const looseFiles = files.filter((f) => !body.includes(`attachment:${f.id}`));

  return (
    <Panel className="grid gap-3">
      <h2 className="post-title text-center" data-long={title.length > TITLE_LONG || undefined}>
        {title || 'Untitled'}
      </h2>
      <Markdown
        className="post-body"
        text={body || '_Nothing written yet._'}
        community={cid}
        files={files}
      />
      <FileList
        files={looseFiles}
        onOpenImage={(f) => {
          const src = f.data ?? f.url;
          if (src) openImage(src, f.name, f.download);
        }}
      />
    </Panel>
  );
}

export function TagsRow({ tags }: { readonly tags: readonly string[] }) {
  return (
    <div className="flex items-center gap-2 flex-wrap small">
      <Label className="icon-text">
        <Icon name="tag" />
        Tags
      </Label>
      {tags.map((t) => (
        <span key={t} className="ref ref--tag">
          #{t}
        </span>
      ))}
    </div>
  );
}

export function PublishBar({
  canDiscard,
  badge,
  busy,
  communityName,
  onDiscard,
  onPublish,
}: {
  readonly canDiscard: boolean;
  readonly badge: SaveState | null;
  readonly busy: boolean;
  readonly communityName: string | null;
  readonly onDiscard: () => void;
  readonly onPublish: () => void;
}) {
  return (
    <div className="flex items-center justify-between gap-2 flex-wrap">
      {canDiscard ? (
        <Button size="small" variant="borderless" onClick={onDiscard}>
          <Icon name="trash" />
          Discard draft
        </Button>
      ) : null}

      {badge ? (
        <span className="show-mobile">
          <SaveBadge saveState={badge} />
        </span>
      ) : null}

      <Button
        variant="reversed"
        busy={busy}
        className="post-to"
        style={{ marginInlineStart: 'auto' }}
        title={communityName ? `Post to ${communityName}` : undefined}
        onClick={onPublish}
      >
        <Icon name="send" />
        <span className="truncate">{communityName ? `Post to ${communityName}` : 'Post'}</span>
      </Button>
    </div>
  );
}
