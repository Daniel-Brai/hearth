import { Icon } from '@/design-system';
import { tintStyle } from '@/domain/format';
import type { PostKind } from '@/domain/types';
import { asIconName } from '@/pages/edit-community/colors';

type KindPickerProps = {
  readonly kinds: readonly PostKind[];
  readonly value: string;
  readonly onChange: (next: string) => void;
};

export function KindPicker({ kinds, value, onChange }: KindPickerProps) {
  return (
    <div className="kind-picker" role="radiogroup" aria-label="Kind of post">
      {kinds.map((k) => (
        <label key={k.name} className="kind-option" style={tintStyle(k.hue)}>
          <input
            type="radio"
            name="kind"
            value={k.name}
            checked={value === k.name}
            onChange={() => onChange(k.name)}
          />
          <span className="kind-option__icon">
            <Icon name={asIconName(k.icon) ?? 'shapes'} />
          </span>
          <span>{k.name}</span>
          {k.mods ? (
            <span className="kind-option__lock" data-tip="Admins and moderators only">
              <Icon name="lock" />
            </span>
          ) : null}
        </label>
      ))}
    </div>
  );
}
