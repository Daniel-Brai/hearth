import { useState } from 'react';

import { useGateway } from '@/app/gateway-context';
import { Button, cn, Icon } from '@/design-system';
import { closingLabel, nextPicks, pollOpen, share } from '@/domain/polls';
import type { Poll } from '@/domain/types';
import { useNow } from '@/features/schedule/use-now';
import { useUi } from '@/runtime/ui-store';

import './PollCard.css';

export function PollCard({
  chatKey,
  messageId,
  question,
  poll,
  canClose,
  live,
}: {
  readonly chatKey: string;
  readonly messageId: string;
  readonly question: string;
  readonly poll: Poll;
  readonly canClose: boolean;
  /** Shown on top of a live voice room rather than in the chat */
  readonly live?: boolean | undefined;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const now = useNow();
  const [busy, setBusy] = useState(false);

  const open = pollOpen(poll, now);
  const mine = new Set(poll.mine);
  const closing = closingLabel(poll, now);

  const pick = async (optionId: string) => {
    const r = await gateway.chat.vote(chatKey, messageId, nextPicks(poll, optionId));
    if (!r.ok) flash(r.error);
  };

  const close = async () => {
    setBusy(true);

    try {
      const r = await gateway.chat.closePoll(chatKey, messageId);
      flash(r.ok ? 'Poll closed' : r.error);
    } finally {
      setBusy(false);
    }
  };

  return (
    <section
      className={cn('poll', live && 'poll--live', !open && 'is-closed')}
      id={'poll-' + messageId}
      aria-label={question}
    >
      <header className="poll__head">
        <span className="poll__kind">
          <Icon name="poll" />
          {live ? 'Live poll' : 'Poll'}
        </span>
        <span className="poll__how">{poll.multiple ? 'Pick any' : 'Pick one'}</span>
      </header>

      <p className="poll__question">{question}</p>

      <ul className="poll__options">
        {poll.options.map((option) => {
          const picked = mine.has(option.id);
          const percent = share(poll, option.votes);

          return (
            <li key={option.id}>
              <button
                type="button"
                className={cn('poll__option', picked && 'is-picked')}
                aria-pressed={picked}
                disabled={!open}
                onClick={() => void pick(option.id)}
              >
                <span className="poll__bar" style={{ inlineSize: percent + '%' }} />
                <span className="poll__label">{option.label}</span>
                <span className="poll__share">
                  {picked ? <Icon name="check" /> : null}
                  {percent}%
                </span>
              </button>
            </li>
          );
        })}
      </ul>

      <footer className="poll__foot">
        <span>{votersText(poll.voters)}</span>
        {closing ? <span className="poll__closing">{closing}</span> : null}
        {open && canClose ? (
          <Button size="tiny" className="poll__close" busy={busy} onClick={() => void close()}>
            Close poll
          </Button>
        ) : null}
      </footer>
    </section>
  );
}

function votersText(voters: number): string {
  if (!voters) return 'No votes yet';

  return voters === 1 ? '1 person voted' : `${voters} people voted`;
}
