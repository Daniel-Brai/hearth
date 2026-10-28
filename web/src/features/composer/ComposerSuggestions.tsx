import { Avatar, Icon } from '@/design-system';
import { useAppState } from '@/data/store';
import { initials, person, photoOf } from '@/domain/selectors';
import type { Suggestion, SuggestKind } from './composer-text';

const TITLES: Record<SuggestKind, string> = {
  '@': 'People',
  '#': 'Rooms and tags',
  '/': 'Commands',
  sound: 'Sounds',
};

export function ComposerSuggestions({
  id,
  kind,
  items,
  index,
  onPick,
  onHover,
}: {
  readonly id: string;
  readonly kind: SuggestKind;
  readonly items: readonly Suggestion[];
  readonly index: number;
  readonly onPick: (s: Suggestion) => void;
  readonly onHover: (i: number) => void;
}) {
  const title = TITLES[kind];

  return (
    <div className="ac" role="listbox" id={id} aria-label={title}>
      <div className="ac__title">{title}</div>
      {items.map((it, i) => (
        <button
          key={it.label + i}
          type="button"
          className="ac__item"
          role="option"
          aria-selected={i === index}
          aria-disabled={it.disabled || undefined}
          onMouseDown={(e) => {
            e.preventDefault();
            onPick(it);
          }}
          onMouseEnter={() => onHover(i)}
        >
          <span className="ac__icon">
            {it.person ? <PersonSuggestionAvatar id={it.person} /> : <Icon name={it.icon} />}
          </span>
          <span className="ac__label">
            <span>{it.label}</span>
            <span className="ac__sub">{it.sub}</span>
          </span>
          <span className="ac__hint">{it.disabled ? it.reason : it.hint}</span>
        </button>
      ))}
    </div>
  );
}

function PersonSuggestionAvatar({ id }: { readonly id: string }) {
  const view = useAppState((state) => ({
    hue: person(state, id).hue,
    initials: initials(state, id),
    photo: photoOf(state, id),
  }));

  return <Avatar size="xs" hue={view.hue} initials={view.initials} photo={view.photo} />;
}
