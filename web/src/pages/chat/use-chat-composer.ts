import { useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { displayName } from '@/domain/selectors';
import type { Attachment, Message } from '@/domain/types';
import { isTune, playTune, sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import type { ChatTarget } from './chat-select';

export function useChatComposer({
  target,
  messages,
  me,
  soundsOn,
  onSent,
}: {
  readonly target: ChatTarget;
  readonly messages: readonly Message[];
  readonly me: string | null;
  readonly soundsOn: boolean;
  readonly onSent: () => void;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);

  const [text, setText] = useState('');
  const [files, setFiles] = useState<Attachment[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [shake, setShake] = useState(false);
  const [replying, setReplying] = useState<Message | null>(null);
  const [repliedTo, setRepliedTo] = useState<ReadonlySet<string>>(() => new Set());
  const replyingName = useAppState((state) => (replying ? displayName(state, replying.who) : null));
  const [editing, setEditing] = useState<Message | null>(null);
  const [draft, setDraft] = useState<{ text: string; files: Attachment[] } | null>(null);

  const startEdit = (id: string) => {
    const m = messages.find((x) => x.id === id);

    if (!m) return;

    if (!editing) setDraft({ text, files });
    setReplying(null);
    setEditing(m);
    setText(m.text);
    setFiles(m.files ?? []);
    setError(null);
    document.getElementById('composer')?.focus();
  };

  const stopEdit = () => {
    setEditing(null);
    setText(draft?.text ?? '');
    setFiles(draft?.files ?? []);
    setDraft(null);
  };

  const saveEdit = (m: Message) => {
    if (!text.trim() && !files.length) {
      stopEdit();
      ask({
        title: 'Delete this message?',
        body: 'You removed everything in it, so saving would leave it empty. It will be removed for everyone in the room.',
        action: 'Delete message',
        onConfirm: () => {
          gateway.chat.remove(target.key, m.id);
          flash('Message deleted');
        },
      });
      return;
    }

    const r = gateway.chat.edit(target.key, m.id, { text, files });

    if (!r.ok) {
      setError(r.error);
      return;
    }

    stopEdit();
  };

  const send = () => {
    if (editing) {
      saveEdit(editing);
      return;
    }

    const r = gateway.chat.send(target.key, text, { files, parent: replying?.id ?? null });

    if (!r.ok) {
      setError(r.error);
      setShake(true);
      window.setTimeout(() => setShake(false), 500);
      sfx('error');

      return;
    }

    if (r.value.sound && isTune(r.value.sound) && soundsOn) playTune(r.value.sound);

    setText('');
    setFiles([]);
    setError(null);

    if (replying) {
      const answered = replying.id;

      setRepliedTo((ids) => new Set(ids).add(answered));
      setReplying(null);

      return;
    }

    onSent();
  };

  const editLast = () => {
    const last = messages.findLast((m) => m.who === me && !m.system);
    if (last) startEdit(last.id);
  };

  const replyTo = (m: Message) => {
    if (editing) stopEdit();
    setReplying((current) => (current?.id === m.id ? null : m));
    document.getElementById('composer')?.focus();
  };

  return {
    text,
    setText,
    files,
    setFiles,
    error,
    shake,
    editing,
    replying,
    replyingName,
    repliedTo,
    startEdit,
    stopEdit,
    send,
    editLast,
    replyTo,
    stopReplying: () => setReplying(null),
  };
}

export type ChatComposerState = ReturnType<typeof useChatComposer>;
