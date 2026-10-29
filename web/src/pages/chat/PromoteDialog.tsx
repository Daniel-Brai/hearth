import { useState, type CSSProperties } from 'react';
import { useNavigate } from 'react-router';
import {
  Avatar,
  Button,
  Dialog,
  DialogClose,
  DialogFooter,
  DialogTitle,
  Field,
  Icon,
  Input,
  Label,
  type IconName,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { tintStyle } from '@/domain/format';
import { authorName, initials, person, photoOf, postableKinds } from '@/domain/selectors';
import type { Message } from '@/domain/types';
import { Markdown } from '@/features/markdown/Markdown';
import { plainTextWithoutCode } from '@/features/markdown/plain-text';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { promoteKind, type ChatTarget } from './chat-select';

type PromoteDialogProps = {
  readonly cid: string;
  readonly target: ChatTarget;
  readonly messages: readonly Message[];
  readonly onClose: () => void;
  readonly onDone: () => void;
};

export function PromoteDialog({ cid, target, messages, onClose, onDone }: PromoteDialogProps) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);

  const kinds = useAppState((state) => postableKinds(state, cid, false));

  const first = plainTextWithoutCode(messages[0]?.text ?? '');

  const [title, setTitle] = useState(first.length > 70 ? first.slice(0, 68) + '…' : first);
  const [kind, setKind] = useState(() => promoteKind(kinds, first));
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    const r = await gateway.chat.promote(
      target.key,
      messages.map((m) => m.id),
      { title, kind },
    );

    if (!r.ok) {
      setError(r.error);
      return;
    }

    onDone();
    flash('Post created from chat');
    void navigate(routes.post(cid, r.value.post.id, r.value.post.title));
  };

  return (
    <Dialog open onClose={onClose} width="36rem" labelledBy="promote-title-h">
      <DialogClose onClick={onClose} />

      <form
        className="dialog__body"
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        <DialogTitle id="promote-title-h">Turn this into a post</DialogTitle>

        <p className="subtle small text-center">
          The first message becomes the post and the rest become replies. The room gets a link so
          the conversation can continue there.
        </p>

        <div className="flex justify-center">
          <div className="kind-picker" role="radiogroup" aria-label="Kind of post">
            {kinds.map((k) => (
              <label key={k.name} className="kind-option" style={tintStyle(k.hue) as CSSProperties}>
                <input
                  type="radio"
                  name="promote-kind"
                  value={k.name}
                  checked={kind === k.name}
                  onChange={() => setKind(k.name)}
                />
                <span className="kind-option__icon">
                  <Icon name={k.icon as IconName} />
                </span>
                <span>{k.name}</span>
              </label>
            ))}
          </div>
        </div>

        <Field label="Title" error={error}>
          <Input
            id="promote-title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={120}
            placeholder="Name the question or topic"
            autoFocus
          />
        </Field>

        <div className="grid gap-3 overflow-y-auto p-[0.2rem] max-h-64">
          {messages.map((m, i) => (
            <PickedMessage key={m.id} message={m} first={i === 0} cid={cid} />
          ))}
        </div>

        <DialogFooter>
          <Button onClick={onClose}>Cancel</Button>
          <Button type="submit" variant="reversed">
            <Icon name="megaphone" />
            Create post
          </Button>
        </DialogFooter>
      </form>
    </Dialog>
  );
}

function PickedMessage({
  message,
  first,
  cid,
}: {
  readonly message: Message;
  readonly first: boolean;
  readonly cid: string | null;
}) {
  const view = useAppState((state) => ({
    name: authorName(state, message.who),
    hue: person(state, message.who).hue,
    initials: initials(state, message.who),
    photo: photoOf(state, message.who),
  }));

  return (
    <div className="flex gap-2 small">
      <Avatar size="xs" hue={view.hue} initials={view.initials} photo={view.photo} />

      <div className="grid gap-1 min-w-0">
        <Label>{(first ? 'Post' : 'Reply') + ' · ' + view.name}</Label>
        <Markdown text={message.text} community={cid} files={message.files ?? []} />
      </div>
    </div>
  );
}
