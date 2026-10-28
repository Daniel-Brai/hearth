import { Icon } from '@/design-system';
import { useAppState } from '@/data/store';
import { displayName } from '@/domain/selectors';

type ReplyingToProps = {
  readonly who: string;
  readonly target: string;
};

export function ReplyingTo({ who, target }: ReplyingToProps) {
  const name = useAppState((state) => displayName(state, who));

  const jump = () => {
    const el = document.getElementById(target);

    if (!el) return;

    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.remove('is-pointed');
    // Restarts the flash when the same reply is pointed at twice
    void el.offsetWidth;
    el.classList.add('is-pointed');
  };

  return (
    <button
      type="button"
      className="replying-to"
      onClick={jump}
      aria-label={`Replying to ${name}. Show that reply`}
    >
      <Icon name="reply" />
      <span className="truncate">{name}</span>
    </button>
  );
}
