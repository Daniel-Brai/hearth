import { Button, Icon, IconButton, OriginNote } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { SOUNDS } from '@/domain/catalog';
import { plural } from '@/domain/format';
import type { Message } from '@/domain/types';
import { Composer } from '@/features/composer/Composer';
import { useUi } from '@/runtime/ui-store';
import type { ChatTarget } from './chat-select';
import type { ChatComposerState } from './use-chat-composer';

export function SelectBar({
  count,
  canPromote,
  onCancel,
  onPromote,
}: {
  readonly count: number;
  readonly canPromote: boolean;
  readonly onCancel: () => void;
  readonly onPromote: () => void;
}) {
  const label = count
    ? plural(count, 'message') + ' selected'
    : 'Pick the messages that belong in the post';

  return (
    <div className="select-bar">
      <span>{label}</span>

      <div className="flex items-center gap-1">
        <Button
          size="small"
          variant="borderless"
          className="[--btn-color:var(--color-canvas)]"
          onClick={onCancel}
        >
          Cancel
        </Button>
        <Button size="small" disabled={!canPromote} onClick={onPromote}>
          <Icon name="megaphone" />
          Promote to post
        </Button>
      </div>
    </div>
  );
}

export function MessageBox({
  target,
  title,
  canChat,
  joined,
  communityName,
  composer,
}: {
  readonly target: ChatTarget;
  readonly title: string;
  readonly canChat: boolean;
  readonly joined: boolean;
  readonly communityName: string | null;
  readonly composer: ChatComposerState;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const { editing, replying, replyingName } = composer;

  const join = () => {
    if (!target.cid) return;

    const r = gateway.communities.join(target.cid);
    if (!r.ok) flash(r.error);
  };

  return (
    <div className="grid grid-cols-[minmax(0,1fr)] gap-1">
      <div className="typing" aria-live="polite" />

      {canChat ? (
        <Composer
          id="composer"
          variant="chat"
          value={composer.text}
          onChange={composer.setText}
          onSubmit={composer.send}
          placeholder={composerPlaceholder(editing, replyingName, title)}
          sendLabel={editing ? 'Save' : 'Send'}
          maxLength={4000}
          community={target.cid}
          commands={gateway.chat.commands(target.key)}
          sounds={SOUNDS}
          attachments={composer.files}
          onAttachmentsChange={composer.setFiles}
          error={composer.error}
          shake={composer.shake}
          onEditLast={composer.editLast}
          onEscape={escapeComposer(editing, replying, composer.stopEdit, composer.stopReplying)}
          beforeSend={
            <ComposerCancel
              editing={!!editing}
              replyingName={replyingName}
              onStopEditing={composer.stopEdit}
              onStopReplying={composer.stopReplying}
            />
          }
        />
      ) : (
        <ReadOnlyNote joined={joined} communityName={communityName} onJoin={join} />
      )}
    </div>
  );
}

function ReadOnlyNote({
  joined,
  communityName,
  onJoin,
}: {
  readonly joined: boolean;
  readonly communityName: string | null;
  readonly onJoin: () => void;
}) {
  if (joined) {
    return (
      <OriginNote>
        <span>
          Your role in <strong>{communityName}</strong> can read this room but not post in it.
        </span>
      </OriginNote>
    );
  }

  return (
    <OriginNote>
      <span>
        Join <strong>{communityName}</strong> to chat here.
      </span>
      <Button size="tiny" variant="reversed" onClick={onJoin}>
        <Icon name="plus" />
        Join
      </Button>
    </OriginNote>
  );
}

function composerPlaceholder(editing: Message | null, replyingName: string | null, title: string) {
  if (editing) return editing.files?.length ? 'Add a message' : 'Edit message';
  if (replyingName) return 'Reply to ' + replyingName;
  return 'Message ' + title;
}

function escapeComposer(
  editing: Message | null,
  replying: Message | null,
  stopEdit: () => void,
  stopReply: () => void,
) {
  if (editing) return stopEdit;
  if (replying) return stopReply;
  return undefined;
}

function ComposerCancel({
  editing,
  replyingName,
  onStopEditing,
  onStopReplying,
}: {
  readonly editing: boolean;
  readonly replyingName: string | null;
  readonly onStopEditing: () => void;
  readonly onStopReplying: () => void;
}) {
  if (!editing && !replyingName) return null;

  const label = editing ? 'Stop editing' : 'Stop replying to ' + replyingName;

  return (
    <IconButton
      size="tiny"
      variant="borderless"
      onClick={editing ? onStopEditing : onStopReplying}
      aria-label={label}
      data-tip={editing ? 'Stop editing' : 'Stop replying'}
    >
      <Icon name="x" />
    </IconButton>
  );
}
