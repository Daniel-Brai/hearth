import { useAppState } from '@/data/store';
import { mayClosePoll, newestOpenPoll } from '@/domain/selectors';
import { PollCard } from '@/features/polls/PollCard';
import { useNow } from '@/features/schedule/use-now';

/** The newest open poll from the room's chat, kept in view while people talk */
export function LivePoll({ cid, rid }: { readonly cid: string; readonly rid: string }) {
  const key = cid + '/' + rid;
  const now = useNow();

  const message = useAppState((state) => newestOpenPoll(state, key, now));
  const canClose = useAppState(
    (state) => message !== null && mayClosePoll(state, cid, message.who),
  );

  if (!message?.poll) return null;

  return (
    <PollCard
      live
      chatKey={key}
      messageId={message.id}
      question={message.text}
      poll={message.poll}
      canClose={canClose}
    />
  );
}
