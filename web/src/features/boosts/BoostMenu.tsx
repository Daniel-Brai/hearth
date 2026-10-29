import { useState, type ReactNode } from 'react';
import { Button, Emoji, EmojiPicker, Menu, cn, preloadEmojiPicker, useMenu } from '@/design-system';
import type { Boost } from '@/domain/types';

export type BoostMenuProps = {
  readonly onPick: (key: string) => void;
  readonly boosts: readonly Boost[];
  readonly trigger: (props: { toggle: () => void; open: boolean }) => ReactNode;
  readonly up?: boolean | undefined;
};

export function BoostMenu({ onPick, boosts, trigger, up }: BoostMenuProps) {
  const pick = (key: string) => {
    if (!boosts.some((b) => b.e === key && b.mine)) onPick(key);
  };

  return (
    <Menu
      left
      up={up}
      popupClassName="p-0 overflow-hidden"
      trigger={(props) => (
        // Loads the picker early so it opens without a placeholder
        <span className="contents" onPointerEnter={preloadEmojiPicker} onFocus={preloadEmojiPicker}>
          {trigger(props)}
        </span>
      )}
    >
      <BoostPicker onPick={pick} />
    </Menu>
  );
}

function BoostPicker({ onPick }: { readonly onPick: (key: string) => void }) {
  const menu = useMenu();
  const [words, setWords] = useState('');

  const pick = (key: string) => {
    onPick(key);
    menu?.close();
  };

  return (
    <div className="grid">
      <EmojiPicker onPick={pick} />

      <form
        className="flex items-center gap-1 p-1 border-t border-ink-lighter"
        onSubmit={(e) => {
          e.preventDefault();

          const w = words.trim().slice(0, 16);

          if (!w) return;
          setWords('');
          pick(w);
        }}
      >
        <input
          className="input"
          style={{ minBlockSize: '2.2rem', fontSize: '0.9rem' }}
          placeholder="Or boost with words"
          maxLength={16}
          value={words}
          onChange={(e) => setWords(e.target.value)}
          aria-label="Boost with words"
        />
        <Button type="submit" size="small" variant="reversed">
          Boost
        </Button>
      </form>
    </div>
  );
}

export function Boosts({
  boosts,
  onToggle,
  disabled,
  className,
}: {
  readonly boosts: readonly Boost[];
  readonly onToggle: (key: string) => void;
  readonly disabled?: boolean | undefined;
  readonly className?: string | undefined;
}) {
  if (!boosts.length) return null;

  return (
    <div className={cn('boosts', className)}>
      {boosts.map((b) => (
        <button
          key={b.e}
          type="button"
          className={cn('boost', b.mine && 'mine')}
          disabled={disabled}
          onClick={() => onToggle(b.e)}
          aria-pressed={b.mine}
        >
          <Emoji value={b.e} />
          <span className="tabular">{b.n}</span>
        </button>
      ))}
    </div>
  );
}
