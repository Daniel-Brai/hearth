import { useState } from 'react';

import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { cn, Icon, IconButton } from '@/design-system';
import { authorName } from '@/domain/selectors';
import type { Message } from '@/domain/types';
import { plainText } from '@/features/markdown/plain-text';
import { useUi } from '@/runtime/ui-store';

const NONE: Message[] = [];

export function PinnedBar({
  chatKey,
  canPin,
}: {
  readonly chatKey: string;
  readonly canPin: boolean;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const pins = useAppState((state) => state.pins[chatKey] ?? NONE);
  const [shown, setShown] = useState(0);

  const pin = pins.length ? pins[shown % pins.length] : undefined;
  const name = useAppState((state) => (pin ? authorName(state, pin.who) : ''));

  if (!pin) return null;

  const jump = () => {
    const message = document.getElementById('msg-' + pin.id);

    if (message) {
      message.scrollIntoView({ block: 'center', behavior: 'smooth' });
      message.classList.add('is-flashed');
      message.addEventListener('animationend', () => message.classList.remove('is-flashed'), {
        once: true,
      });
    } else {
      flash('That message is older than this chat shows.');
    }

    setShown((n) => (n + 1) % pins.length);
  };

  const unpin = () =>
    void gateway.chat.unpin(chatKey, pin.id).then((r) => flash(r.ok ? 'Unpinned' : r.error));

  const text = plainText(pin.text) || (pin.files?.length ? 'A file' : 'A message');

  return (
    <div className="pin-bar" id="pin-bar">
      {pins.length > 1 ? (
        <span className="pin-bar__marks" aria-hidden="true">
          {pins.map((p) => (
            <span key={p.id} className={cn('pin-bar__mark', p.id === pin.id && 'is-on')} />
          ))}
        </span>
      ) : null}

      <button
        type="button"
        className="pin-bar__jump"
        onClick={jump}
        aria-label={`Pinned message from ${name}. Go to it`}
      >
        <Icon name="pin" />
        <span className="pin-bar__text">
          <strong>{name}</strong>
          <span className="truncate">{text}</span>
        </span>
      </button>

      {canPin ? (
        <IconButton
          variant="borderless"
          size="tiny"
          className="pin-bar__unpin"
          aria-label="Unpin"
          data-tip="Unpin"
          onClick={unpin}
        >
          <Icon name="x" />
        </IconButton>
      ) : null}
    </div>
  );
}
