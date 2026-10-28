import { useState } from 'react';
import { Button, Icon, Textarea } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import type { PostPatch } from '@/data/gateway';
import { useAppState } from '@/data/store';
import { isTech, kindInfo, postableKinds } from '@/domain/selectors';
import type { Attachment, Post } from '@/domain/types';
import { Composer } from '@/features/composer/Composer';
import { useUi } from '@/runtime/ui-store';
import { ModeToggle, PostPreview } from '@/pages/compose/ComposeParts';
import { KindPicker } from '@/pages/compose/KindPicker';
import { LeaveDialog } from '@/pages/compose/LeaveDialog';
import { useLeaveGuard } from '@/pages/compose/use-leave-guard';
import '@/pages/compose/ComposePage.css';
import { TITLE_MAX } from '@/domain/catalog';

const sameFiles = (a: readonly Attachment[], b: readonly Attachment[]) =>
  a.length === b.length && a.every((f, i) => f.id === b[i]?.id);

export function PostEditor({ post, onDone }: { readonly post: Post; readonly onDone: () => void }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  const [original] = useState<PostPatch>(() => ({
    title: post.title,
    body: post.body.join('\n\n'),
    kind: post.kind,
    files: post.files ?? [],
  }));

  const [fields, setFields] = useState(original);
  const [preview, setPreview] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // A kind they can no longer post stays on offer so the post keeps it
  const kinds = useAppState((state) => {
    const postable = postableKinds(state, post.c);
    return postable.some((k) => k.name === original.kind)
      ? postable
      : [kindInfo(state, post.c, original.kind), ...postable];
  });

  const kind = useAppState((state) => kindInfo(state, post.c, fields.kind));
  const tech = useAppState((state) => isTech(state, post.c));

  const dirty =
    fields.title !== original.title ||
    fields.body !== original.body ||
    fields.kind !== original.kind ||
    !sameFiles(fields.files, original.files);

  const guard = useLeaveGuard(dirty);

  const save = async () => {
    if (busy) return;
    if (!dirty) return onDone();
    if (!fields.title.trim()) return setError('A post needs a title.');
    setBusy(true);

    let r;

    try {
      r = await gateway.posts.edit(post.id, fields);
    } finally {
      setBusy(false);
    }

    if (!r.ok) return setError(r.error);
    guard.allowLeave();
    flash('Saved');
    onDone();
  };

  return (
    <div className="post-edit" id="post-edit">
      <KindPicker
        kinds={kinds}
        value={fields.kind}
        onChange={(k) => setFields((f) => ({ ...f, kind: k }))}
      />

      <Textarea
        id="post-edit-title"
        bare
        className="compose-title post-edit__title"
        rows={1}
        value={fields.title}
        onChange={(e) => setFields((f) => ({ ...f, title: e.target.value }))}
        onKeyDown={(e) => {
          if (e.key === 'Escape') onDone();
          if (e.key !== 'Enter') return;
          e.preventDefault();

          if (e.metaKey || e.ctrlKey) void save();
          else document.getElementById('post-edit-body')?.focus();
        }}
        maxLength={TITLE_MAX}
        countFrom={TITLE_MAX - 30}
        placeholder={kind.hint}
        aria-label="Title"
        autoFocus
      />

      <ModeToggle preview={preview} onChange={setPreview} />

      <div className="post-edit__body" hidden={preview}>
        <Composer
          id="post-edit-body"
          variant="body"
          value={fields.body}
          onChange={(body) => setFields((f) => ({ ...f, body }))}
          onSubmit={() => void save()}
          onEscape={onDone}
          placeholder={kind.body + (tech ? ' Code goes in ``` fences.' : '')}
          label="Post text"
          maxLength={20000}
          community={post.c}
          attachments={fields.files}
          onAttachmentsChange={(files) => setFields((f) => ({ ...f, files }))}
          error={error}
          disabled={busy}
        />
      </div>

      {preview ? (
        <PostPreview cid={post.c} title={fields.title} body={fields.body} files={fields.files} />
      ) : null}

      <div className="post-edit__bar">
        <span className="x-small subtle hide-narrow">Ctrl or ⌘ Enter saves, Esc cancels</span>
        <Button id="post-edit-cancel" variant="borderless" onClick={onDone}>
          Cancel
        </Button>
        <Button
          id="post-edit-save"
          variant="reversed"
          busy={busy}
          disabled={!fields.title.trim()}
          onClick={() => void save()}
        >
          <Icon name="check" />
          Save changes
        </Button>
      </div>

      <LeaveDialog
        blocker={guard.blocker}
        title="Leave without saving?"
        text="Your changes to this post will be lost."
        stay="Keep editing"
        leave="Leave"
      />
    </div>
  );
}
