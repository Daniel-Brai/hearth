import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import type { ScheduledMessage } from '@/domain/types';
import { ScheduledNote, type ScheduledWords } from '@/features/schedule/ScheduledNote';

const WORDS: ScheduledWords = {
  noun: 'message',
  goes: 'Sends',
  now: 'Send now',
  sentNow: 'Message sent',
  deleted: 'Scheduled message deleted',
};

export function ScheduledMessages({
  chatKey,
  onEdit,
}: {
  readonly chatKey: string;
  readonly onEdit: (item: ScheduledMessage) => void;
}) {
  const gateway = useGateway();
  const items = useAppState((state) => state.scheduled.filter((s) => s.key === chatKey));
  const find = (id: string) => items.find((s) => s.id === id);

  return (
    <ScheduledNote
      id="scheduled-note"
      entries={items.map((s) => ({
        id: s.id,
        sendAt: s.sendAt,
        title: null,
        text: s.text,
        files: s.files.length,
        failure: s.failure,
      }))}
      words={WORDS}
      actions={{
        sendNow: gateway.chat.sendNow,
        reschedule: (id, at) => gateway.chat.reschedule(id, at.toISOString()),
        edit: (id) => {
          const item = find(id);
          if (item) onEdit(item);
        },
        remove: gateway.chat.unschedule,
      }}
    />
  );
}
